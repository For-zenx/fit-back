import 'dart:async';
import 'dart:math';

import 'distance_source.dart';

/// Simulated sensor for development without hardware.
/// Emits a sine wave (the moving plate) plus noise, at [hertz].
class SimulatedDistanceSource implements DistanceSource {
  /// Sensor output rate. Matches firmware normal mode (~20 Hz).
  final int hertz;

  /// Resting distance of the measured point (cm).
  final double baseCm;

  /// Peak-to-peak travel of the rep (cm).
  final double amplitudeCm;

  /// Seconds per rep (one full up-down cycle).
  final double repPeriodSeconds;

  /// Gaussian noise standard deviation (cm). Ultrasonic sensors are noisy.
  final double noiseCm;

  final _controller = StreamController<DistanceSample>.broadcast();
  Timer? _timer;
  double _t = 0;
  final _random = Random();

  SimulatedDistanceSource({
    this.hertz = 20,
    this.baseCm = 30.0,
    this.amplitudeCm = 20.0,
    this.repPeriodSeconds = 3.0,
    this.noiseCm = 0.4,
  });

  @override
  Stream<DistanceSample> get stream => _controller.stream;

  @override
  Future<void> connect() async {
    _t = 0;
    final period = Duration(milliseconds: (1000 / hertz).round());
    _timer = Timer.periodic(period, (_) => _emit());
  }

  void _emit() {
    _t += 1.0 / hertz;
    final angle = 2 * pi * _t / repPeriodSeconds;
    // Sine centered at baseCm + amplitude/2 so distance stays positive.
    final ideal = baseCm + (amplitudeCm / 2) * (1 - cos(angle));
    final noise = _gaussian() * noiseCm;
    _controller.add(DistanceSample(_t, ideal + noise));
  }

  double _gaussian() {
    // Box-Muller on two uniform samples.
    final u1 = max(_random.nextDouble(), 1e-10);
    final u2 = _random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _controller.close();
}

/// Replays a recorded signal: list of `t_seconds,distance_cm` pairs
/// (same CSV format the firmware prints over Serial).
class ReplayDistanceSource implements DistanceSource {
  final List<DistanceSample> samples;
  final _controller = StreamController<DistanceSample>.broadcast();
  Timer? _timer;
  int _index = 0;

  ReplayDistanceSource(this.samples);

  /// Parses lines like `"12.345,23.45"`.
  factory ReplayDistanceSource.fromCsv(String csv) {
    final samples = <DistanceSample>[];
    for (final line in csv.split('\n')) {
      final parts = line.trim().split(',');
      if (parts.length != 2) continue;
      final t = double.tryParse(parts[0]);
      final d = double.tryParse(parts[1]);
      if (t != null && d != null) samples.add(DistanceSample(t, d));
    }
    return ReplayDistanceSource(samples);
  }

  @override
  Stream<DistanceSample> get stream => _controller.stream;

  @override
  Future<void> connect() async {
    _index = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_index < samples.length) {
        _controller.add(samples[_index++]);
      }
    });
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => _controller.close();
}
