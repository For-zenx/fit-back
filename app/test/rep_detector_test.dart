import 'dart:math';

import 'package:fitback/core/distance_source.dart';
import 'package:fitback/core/guide_track.dart';
import 'package:fitback/core/rep_detector.dart';
import 'package:fitback/core/simulated_distance_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// Generates a synthetic rep signal: sine between [minCm] and [maxCm],
/// one full cycle per [periodSeconds], sampled at [hertz].
List<DistanceSample> sineSamples({
  required int repCount,
  double minCm = 20,
  double maxCm = 40,
  double periodSeconds = 2.0,
  double hertz = 20,
  double noiseCm = 0,
  int seed = 0,
}) {
  final samples = <DistanceSample>[];
  final rng = Random(seed);
  final totalSeconds = repCount * periodSeconds;
  final count = (totalSeconds * hertz).round();
  final amp = (maxCm - minCm) / 2;
  final mid = minCm + amp;
  for (var i = 0; i < count; i++) {
    final t = i / hertz;
    final noise = noiseCm * (rng.nextDouble() * 2 - 1);
    final d = mid + amp * sin(2 * pi * t / periodSeconds) + noise;
    samples.add(DistanceSample(t, d));
  }
  return samples;
}

RepDetector fedDetector(
  List<DistanceSample> samples, {
  double hysteresisRatio = 0.15,
}) {
  final detector = RepDetector(hysteresisRatio: hysteresisRatio);
  for (final s in samples) {
    detector.addSample(s);
  }
  return detector;
}

void main() {
  group('RepDetector', () {
    test('counts every cycle of a clean sine', () {
      // Boundary cycles may land mid-phase; allow off-by-one.
      final d = fedDetector(sineSamples(repCount: 10));
      expect(d.repCount, inInclusiveRange(9, 10));
    });

    test('ignores noise smaller than hysteresis', () {
      // 0.5 cm of jitter on a 20 cm range must not create reps.
      final d = fedDetector(sineSamples(repCount: 8, noiseCm: 0.5));
      expect(d.repCount, inInclusiveRange(7, 8));
    });

    test('flat signal counts zero reps', () {
      final flat = List.generate(400, (i) => DistanceSample(i / 20.0, 30.0));
      final d = fedDetector(flat);
      expect(d.repCount, 0);
    });

    test('small bounce under threshold counts zero reps', () {
      // +/-0.3 cm oscillation — sensor noise, not a rep.
      final tiny = sineSamples(
        repCount: 20,
        minCm: 30,
        maxCm: 30.6,
        periodSeconds: 0.4,
      );
      final d = fedDetector(tiny);
      expect(d.repCount, 0);
    });

    test('emits RepEvent with phase durations and range', () async {
      final detector = RepDetector();
      final events = <RepEvent>[];
      detector.reps.listen(events.add);
      for (final s in sineSamples(repCount: 5, periodSeconds: 2.0)) {
        detector.addSample(s);
      }
      // Let the broadcast stream deliver.
      await Future.delayed(Duration.zero);
      expect(events.length, inInclusiveRange(4, 5));
      expect(events.last.rangeCm, greaterThan(15));
      expect(events.last.concentricDuration.inMilliseconds, greaterThan(0));
      detector.dispose();
    });

    test('reset returns to zero', () {
      final d = fedDetector(sineSamples(repCount: 4));
      expect(d.repCount, 4);
      d.reset();
      expect(d.repCount, 0);
      expect(d.minCm.isFinite, isFalse);
    });
  });

  group('GuideTrack', () {
    test('uses a fixed tempo and shows one and a half cycles', () {
      final guide = GuideTrack.fromCalibration(minCm: 30, maxCm: 50);
      expect(guide.cycleSeconds, 3);
      expect(guide.visibleSeconds, 4.5);
      expect(guide.targetCm(0), 30);
      expect(guide.targetCm(1.5), 50);
      expect(guide.targetCm(3), 30);
    });

    test('slows the chosen phase without changing calibrated range', () {
      final eccentric = GuideTrack.fromCalibration(
        minCm: 30,
        maxCm: 50,
        mode: WorkoutMode.eccentric,
      );
      final concentric = GuideTrack.fromCalibration(
        minCm: 30,
        maxCm: 50,
        mode: WorkoutMode.concentric,
      );
      expect(eccentric.upSeconds, 1);
      expect(eccentric.downSeconds, 3);
      expect(concentric.upSeconds, 3);
      expect(concentric.downSeconds, 1);
      for (final guide in [eccentric, concentric]) {
        expect(guide.minCm, 30);
        expect(guide.maxCm, 50);
        expect(guide.visibleSeconds, 6);
      }
    });
  });

  group('ReplayDistanceSource', () {
    test('parses firmware CSV format', () {
      final src = ReplayDistanceSource.fromCsv('''
0.000,20.00
0.050,20.45
0.100,21.10
bad line
0.150,21.80
''');
      expect(src.samples.length, 4);
      expect(src.samples[2].distanceCm, closeTo(21.10, 1e-9));
      expect(src.samples[3].timeSeconds, closeTo(0.15, 1e-9));
      src.dispose();
    });
  });
}
