import 'dart:math';

/// Exercise tempo modality chosen before the set.
enum WorkoutMode { normal, concentric, eccentric }

/// Target path ("the track") the user should follow with the ball.
///
/// Built from the calibrated motion range plus phase durations. The
/// modality reshapes the path: eccentric stretches the descending
/// segment (slower return), concentric stretches the ascending one.
class GuideTrack {
  final double minCm;
  final double maxCm;

  /// Seconds the target takes to go min -> max.
  final double upSeconds;

  /// Seconds the target takes to go max -> min.
  final double downSeconds;

  const GuideTrack({
    required this.minCm,
    required this.maxCm,
    required this.upSeconds,
    required this.downSeconds,
  });

  /// Builds the track from a completed rep and the chosen mode.
  ///
  /// [concentricUp]: true if distance increases during the concentric
  /// phase (depends on sensor placement).
  factory GuideTrack.fromRep({
    required double minCm,
    required double maxCm,
    required Duration concentric,
    required Duration eccentric,
    required bool concentricUp,
    required WorkoutMode mode,
  }) {
    var up = concentric.inMilliseconds / 1000;
    var down = eccentric.inMilliseconds / 1000;
    if (up <= 0) up = 1.0;
    if (down <= 0) down = 1.5;

    // Natural durations come from the user's first rep; the mode
    // stretches the emphasised phase to enforce the tempo.
    switch (mode) {
      case WorkoutMode.eccentric:
        down *= 2.5; // slow, controlled return
      case WorkoutMode.concentric:
        up *= 2.5; // slow, controlled push
      case WorkoutMode.normal:
        break;
    }

    // Map onto the sensor's axis: if distance rises during the
    // concentric phase, "up" on screen is the concentric segment.
    return concentricUp
        ? GuideTrack(
            minCm: minCm,
            maxCm: maxCm,
            upSeconds: up,
            downSeconds: down,
          )
        : GuideTrack(
            minCm: minCm,
            maxCm: maxCm,
            upSeconds: down,
            downSeconds: up,
          );
  }

  factory GuideTrack.fromCalibration({
    required double minCm,
    required double maxCm,
    WorkoutMode mode = WorkoutMode.normal,
  }) {
    final (up, down) = switch (mode) {
      WorkoutMode.normal => (1.5, 1.5),
      WorkoutMode.concentric => (3.0, 1.0),
      WorkoutMode.eccentric => (1.0, 3.0),
    };
    return GuideTrack(
      minCm: minCm,
      maxCm: maxCm,
      upSeconds: up,
      downSeconds: down,
    );
  }

  double get cycleSeconds => upSeconds + downSeconds;
  double get visibleSeconds => cycleSeconds * 1.5;

  /// Target distance at time [t] (seconds), smooth-eased between
  /// extremes so the path looks like the reference's flowing track.
  double targetCm(double t) {
    final phase = t % cycleSeconds;
    final range = maxCm - minCm;
    if (phase < upSeconds) {
      final p = phase / upSeconds;
      return minCm + range * (0.5 - 0.5 * cos(pi * p));
    }
    final p = (phase - upSeconds) / downSeconds;
    return maxCm - range * (0.5 - 0.5 * cos(pi * p));
  }

  /// Times of the next peaks/valleys around [t] (for markers).
  /// Returns events within [t - back, t + ahead].
  List<({double t, double cm, bool isPeak})> extremaAround(
    double t,
    double back,
    double ahead,
  ) {
    final events = <({double t, double cm, bool isPeak})>[];
    final cycle = cycleSeconds;
    // Find the cycle start containing t, then walk a couple of cycles.
    final k = (t / cycle).floor();
    for (var i = k - 1; i <= k + 2; i++) {
      final start = i * cycle;
      events.add((t: start + upSeconds, cm: maxCm, isPeak: true));
      events.add((t: start + cycle, cm: minCm, isPeak: false));
    }
    return events.where((e) => e.t >= t - back && e.t <= t + ahead).toList();
  }
}
