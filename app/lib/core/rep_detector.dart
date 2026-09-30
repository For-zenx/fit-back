import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'distance_source.dart';

/// Which half of the rep we are in, measured between extreme points.
enum RepPhase { concentric, eccentric, idle }

/// Emitted every time a full rep is confirmed.
class RepEvent {
  final int repNumber;
  final Duration concentricDuration;
  final Duration eccentricDuration;
  final double rangeCm;

  const RepEvent({
    required this.repNumber,
    required this.concentricDuration,
    required this.eccentricDuration,
    required this.rangeCm,
  });
}

/// Snapshot of the detector state, emitted on every filtered sample.
class DetectorFrame {
  final double smoothedCm;
  final double minCm;
  final double maxCm;
  final int reps;
  final RepPhase phase;
  final bool calibrated;

  const DetectorFrame({
    required this.smoothedCm,
    required this.minCm,
    required this.maxCm,
    required this.reps,
    required this.phase,
    required this.calibrated,
  });
}

/// Detects reps from a distance stream using median smoothing +
/// hysteresis around the learned motion range.
///
/// Calibration: observes the first samples to learn min/max; the
/// hysteresis threshold is derived from that range (or a fixed floor).
class RepDetector {
  /// Median filter window. Matches the firmware's 5-reading median.
  final int medianWindow;

  /// Fraction of the observed range the signal must travel to confirm
  /// a direction change. Prevents noise double-counts.
  final double hysteresisRatio;

  /// Minimum absolute hysteresis (cm) when the range is still unknown.
  final double minHysteresisCm;

  /// If true, the concentric phase is the one where distance increases.
  /// Depends on where the sensor points; set per machine profile.
  final bool concentricIsUp;

  final _window = Queue<double>();
  final _frames = StreamController<DetectorFrame>.broadcast();
  final _reps = StreamController<RepEvent>.broadcast();

  double _minCm = double.infinity;
  double _maxCm = double.negativeInfinity;
  double? _lastExtremumCm;
  double _lastExtremumT = 0;
  bool _rising = false;
  bool _hasDirection = false;

  int _repCount = 0;
  double _phaseStartT = 0;
  Duration _concentricDuration = Duration.zero;
  Duration _eccentricDuration = Duration.zero;
  bool _peakSeenSinceValley = false;

  Stream<DetectorFrame> get frames => _frames.stream;
  Stream<RepEvent> get reps => _reps.stream;
  int get repCount => _repCount;
  double get minCm => _minCm;
  double get maxCm => _maxCm;

  RepDetector({
    this.medianWindow = 5,
    this.hysteresisRatio = 0.15,
    this.minHysteresisCm = 1.0,
    this.concentricIsUp = true,
  });

  double get _hysteresis {
    final range = _maxCm - _minCm;
    if (range.isFinite && range > 0) {
      return max(range * hysteresisRatio, minHysteresisCm);
    }
    return minHysteresisCm;
  }

  /// Feed one raw sample. Call this for every [DistanceSample] received.
  void addSample(DistanceSample sample) {
    final smoothed = _medianFilter(sample.distanceCm);
    if (smoothed.isNaN) return;

    _minCm = min(_minCm, smoothed);
    _maxCm = max(_maxCm, smoothed);

    _detect(sample.timeSeconds, smoothed);

    _frames.add(DetectorFrame(
      smoothedCm: smoothed,
      minCm: _minCm.isFinite ? _minCm : smoothed,
      maxCm: _maxCm.isFinite ? _maxCm : smoothed,
      reps: _repCount,
      phase: _phase,
      calibrated: _repCount > 0 || _hasDirection,
    ));
  }

  double _medianFilter(double raw) {
    _window.addLast(raw);
    if (_window.length > medianWindow) _window.removeFirst();
    final sorted = _window.toList()..sort();
    return sorted[sorted.length ~/ 2];
  }

  RepPhase get _phase {
    if (!_hasDirection) return RepPhase.idle;
    final risingIsConcentric = concentricIsUp;
    return (_rising == risingIsConcentric)
        ? RepPhase.concentric
        : RepPhase.eccentric;
  }

  void _detect(double t, double d) {
    if (_lastExtremumCm == null) {
      _lastExtremumCm = d;
      _lastExtremumT = t;
      _phaseStartT = t;
      return;
    }

    final h = _hysteresis;
    final delta = d - _lastExtremumCm!;

    if (!_hasDirection) {
      // First confirmed move establishes the initial direction.
      if (delta.abs() >= h) {
        _hasDirection = true;
        _rising = delta > 0;
        _lastExtremumCm = d;
        _lastExtremumT = t;
      }
      return;
    }

    if (_rising) {
      if (d > _lastExtremumCm!) {
        // Still going up: move the peak forward.
        _lastExtremumCm = d;
        _lastExtremumT = t;
      } else if (delta < -h) {
        // Peak confirmed, direction flipped down.
        _onExtremum(isPeak: true, t: _lastExtremumT, nowT: t);
        _rising = false;
        _lastExtremumCm = d;
        _lastExtremumT = t;
      }
    } else {
      if (d < _lastExtremumCm!) {
        _lastExtremumCm = d;
        _lastExtremumT = t;
      } else if (delta > h) {
        // Valley confirmed. A full rep = peak->valley completed.
        _onExtremum(isPeak: false, t: _lastExtremumT, nowT: t);
        _rising = true;
        _lastExtremumCm = d;
        _lastExtremumT = t;
      }
    }
  }

  void _onExtremum({
    required bool isPeak,
    required double t,
    required double nowT,
  }) {
    final duration =
        Duration(milliseconds: ((nowT - _phaseStartT) * 1000).round());
    _phaseStartT = nowT;

    // Rising segment = peak confirmed now; its duration belongs to the
    // phase that just ended.
    if (isPeak) {
      _peakSeenSinceValley = true;
      if (_rising == concentricIsUp) {
        _concentricDuration = duration;
      } else {
        _eccentricDuration = duration;
      }
      return;
    }

    // Valley confirmed: the descending phase just ended.
    if (_rising == concentricIsUp) {
      _eccentricDuration = duration;
    } else {
      _concentricDuration = duration;
    }

    // A rep completes at each valley that follows a real peak.
    if (_peakSeenSinceValley) {
      _peakSeenSinceValley = false;
      _repCount++;
      _reps.add(RepEvent(
        repNumber: _repCount,
        concentricDuration: _concentricDuration,
        eccentricDuration: _eccentricDuration,
        rangeCm: (_maxCm - _minCm).isFinite ? _maxCm - _minCm : 0,
      ));
    }
  }

  void reset() {
    _window.clear();
    _minCm = double.infinity;
    _maxCm = double.negativeInfinity;
    _lastExtremumCm = null;
    _hasDirection = false;
    _rising = false;
    _repCount = 0;
    _phaseStartT = 0;
    _peakSeenSinceValley = false;
    _concentricDuration = Duration.zero;
    _eccentricDuration = Duration.zero;
  }

  void dispose() {
    _frames.close();
    _reps.close();
  }
}
