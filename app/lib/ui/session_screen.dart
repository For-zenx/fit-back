import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/distance_source.dart';
import '../core/guide_track.dart';
import '../core/rep_detector.dart';
import '../core/simulated_distance_source.dart';
import 'motion_wave.dart';

/// Live workout screen: big rep counter, set/weight, timer, and the
/// motion wave fed by a [DistanceSource] (simulator for now).
class SessionScreen extends StatefulWidget {
  final DistanceSource? source;

  const SessionScreen({super.key, this.source});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with SingleTickerProviderStateMixin {
  late final DistanceSource _source;
  late final Ticker _ticker;
  final RepDetector _detector = RepDetector();
  final ValueNotifier<double> _guidePosition = ValueNotifier(0);

  StreamSubscription<DistanceSample>? _sourceSub;
  StreamSubscription<DetectorFrame>? _frameSub;
  StreamSubscription<RepEvent>? _repSub;
  StreamSubscription<ExtremumEvent>? _extremaSub;

  final List<Offset> _wave = [];
  final List<ExtremumEvent> _extrema = [];
  GuideTrack? _guide;
  double _nowSeconds = 0;
  double _lastTickSeconds = 0;
  double _lastMotionTick = 0;
  double _motionAnchorCm = 0;
  int _calibrationReps = 0;
  bool _paused = false;
  bool _resting = false;
  double _currentCm = 0;
  double _minCm = 0;
  double _maxCm = 1;
  int _reps = 0;
  int _setNumber = 1;
  double _weightKg = 24;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _source = widget.source ?? SimulatedDistanceSource();
    // Smooth-scroll ticker: keeps the track moving even if sensor
    // frames arrive late or batched (removes the visible stutter).
    _ticker = createTicker(_onTick);
    _start();
  }

  void _start() {
    _frameSub = _detector.frames.listen(_onFrame);
    _repSub = _detector.reps.listen(_onRep);
    _extremaSub = _detector.extrema.listen(_onExtremum);
    _source.connect();
    _sourceSub = _source.stream.listen((sample) {
      if (!_resting) _detector.addSample(sample);
    });
    _startSetTimer();
  }

  void _startSetTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  void _onTick(Duration elapsed) {
    final seconds = elapsed.inMicroseconds / 1000000;
    if (!_paused && seconds - _lastMotionTick >= 3) {
      _paused = true;
      _ticker.stop();
      setState(() {});
    }
    if (!_paused) {
      _guidePosition.value += seconds - _lastTickSeconds;
    }
    _lastTickSeconds = seconds;
  }

  void _onFrame(DetectorFrame f) {
    if (_resting) return;
    // X axis = real sensor time, always increasing (scroll fix).
    _wave.add(Offset(f.timeSeconds, f.smoothedCm));
    const windowSeconds = 8.0;
    while (_wave.isNotEmpty && _wave.first.dx < f.timeSeconds - windowSeconds) {
      _wave.removeAt(0);
    }
    _extrema.removeWhere((e) => e.timeSeconds < f.timeSeconds - windowSeconds);
    if (_guide != null && (f.smoothedCm - _motionAnchorCm).abs() >= 1.5) {
      _motionAnchorCm = f.smoothedCm;
      _lastMotionTick = _lastTickSeconds;
      if (_paused) {
        _paused = false;
        _lastTickSeconds = 0;
        _lastMotionTick = 0;
        _ticker.start();
      }
    }
    _currentCm = f.smoothedCm;
    _nowSeconds = f.timeSeconds;
    _minCm = f.minCm;
    _maxCm = f.maxCm;
    setState(() {});
  }

  void _onRep(RepEvent e) {
    if (_resting) return;
    setState(() {
      if (_guide == null) {
        _calibrationReps = e.repNumber;
        _guide = GuideTrack.fromCalibration(
          minCm: _detector.minCm,
          maxCm: _detector.maxCm,
        );
        _motionAnchorCm = _currentCm;
        _lastMotionTick = 0;
        _lastTickSeconds = 0;
        _ticker.start();
      }
      _reps = e.repNumber - _calibrationReps;
    });
  }

  void _onExtremum(ExtremumEvent e) {
    if (_resting) return;
    _extrema.add(e);
    setState(() {});
  }

  String get _clockText {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _endSet() {
    // Rest -> next set (simple flow for now).
    _resting = true;
    _ticker.stop();
    _timer?.cancel();
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descanso'),
        content: Text('Set $_setNumber terminado: $_reps reps.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _setNumber++;
                _detector.reset();
                _reps = 0;
                _calibrationReps = 0;
                _paused = false;
                _guidePosition.value = 0;
                _lastMotionTick = 0;
                _lastTickSeconds = 0;
                _motionAnchorCm = _currentCm;
                _elapsed = Duration.zero;
                _resting = false;
                _startSetTimer();
                if (_guide != null) _ticker.start();
              });
            },
            child: const Text('Siguiente set'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sourceSub?.cancel();
    _frameSub?.cancel();
    _repSub?.cancel();
    _extremaSub?.cancel();
    _timer?.cancel();
    _ticker.dispose();
    _guidePosition.dispose();
    _source.disconnect();
    _detector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: close + timer.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 32),
                    onPressed: () {},
                  ),
                  const Spacer(),
                  Text(
                    _clockText,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Set | REPS | kg
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _stat('$_setNumberº', 'SET'),
                  const Spacer(),
                  Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.85,
                                end: 1,
                              ).animate(animation),
                              child: child,
                            ),
                        child: Text(
                          '$_reps',
                          key: ValueKey(_reps),
                          style: const TextStyle(
                            fontSize: 110,
                            fontWeight: FontWeight.bold,
                            height: 0.9,
                          ),
                        ),
                      ),
                      const Text(
                        'REPS',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _stat(_weightKg.toStringAsFixed(0), 'KG'),
                ],
              ),
            ),

            // Motion wave.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: MotionWave(
                        samples: List.unmodifiable(_wave),
                        extrema: List.unmodifiable(_extrema),
                        guide: _guide,
                        currentCm: _currentCm,
                        nowSeconds: _nowSeconds,
                        minCm: _minCm,
                        maxCm: _maxCm,
                        guidePosition: _guidePosition,
                      ),
                    ),
                    if (_guide == null || _paused)
                      Positioned(
                        top: 8,
                        left: 0,
                        right: 0,
                        child: Text(
                          _guide == null
                              ? 'Haz una repetición para calibrar'
                              : 'Pausado · muévete para continuar',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    // Dev readout: current distance.
                    Positioned(
                      left: 8,
                      bottom: 4,
                      child: Text(
                        '${_currentCm.toStringAsFixed(1)} cm',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom actions.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 36),
                    onPressed: () => setState(
                      () => _weightKg = (_weightKg - 2.5).clamp(0, 500),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FilledButton(
                        onPressed: _endSet,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Terminar set',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 36),
                    onPressed: () => setState(
                      () => _weightKg = (_weightKg + 2.5).clamp(0, 500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return SizedBox(
      width: 60,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
