/// A single distance reading from the sensor.
class DistanceSample {
  final double timeSeconds;
  final double distanceCm;

  const DistanceSample(this.timeSeconds, this.distanceCm);
}

/// Abstraction over the distance data origin.
/// Implementations: [BleDistanceSource] (real ESP32) and
/// [SimulatedDistanceSource] (dev/testing). See docs/app-spec.md.
abstract class DistanceSource {
  /// Emits one sample per sensor reading (~20 Hz in normal mode).
  Stream<DistanceSample> get stream;

  Future<void> connect();
  Future<void> disconnect();
}
