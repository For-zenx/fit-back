import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/guide_track.dart';
import '../core/rep_detector.dart';

/// The main motion visual. Two modes:
///
/// - **Warm-up** (no guide yet): moves the ball vertically while
///   the first rep calibrates the range.
/// - **Guided**: a thick target track scrolls under a ball fixed in X;
///   the ball only moves vertically with the real distance, and the
///   user tries to keep it on the track.
class MotionWave extends StatelessWidget {
  /// Recent (timeSeconds, smoothedCm) samples, oldest first.
  final List<Offset> samples;

  /// Detected extrema (warm-up markers).
  final List<ExtremumEvent> extrema;

  /// Active target path; null until the first rep calibrates it.
  final GuideTrack? guide;

  /// Latest smoothed distance (ball height in guided mode).
  final double currentCm;

  /// Latest sensor timestamp (scroll anchor).
  final double nowSeconds;

  final double minCm;
  final double maxCm;
  final ValueListenable<double> guidePosition;
  final bool showRawSignal;

  const MotionWave({
    super.key,
    required this.samples,
    required this.extrema,
    required this.guide,
    required this.currentCm,
    required this.nowSeconds,
    required this.minCm,
    required this.maxCm,
    required this.guidePosition,
    this.showRawSignal = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: guide == null
          ? showRawSignal
                ? _SignalPainter(samples, extrema, minCm, maxCm)
                : _CalibrationPainter(currentCm, minCm, maxCm)
          : _GuidePainter(
              guide: guide!,
              currentCm: currentCm,
              position: guidePosition,
            ),
      size: Size.infinite,
    );
  }
}

// ============================================================
// Warm-up: ball only (raw signal available in dev mode)
// ============================================================

class _CalibrationPainter extends CustomPainter {
  final double currentCm;
  final double minCm;
  final double maxCm;

  _CalibrationPainter(this.currentCm, this.minCm, this.maxCm);

  @override
  void paint(Canvas canvas, Size size) {
    final range = max(maxCm - minCm, 1.0);
    final y = 24 + (1 - (currentCm - minCm) / range) * (size.height - 48);
    _drawBall(canvas, Offset(size.width * 0.28, y.clamp(24, size.height - 24)));
  }

  @override
  bool shouldRepaint(_CalibrationPainter old) =>
      currentCm != old.currentCm || minCm != old.minCm || maxCm != old.maxCm;
}

class _SignalPainter extends CustomPainter {
  final List<Offset> samples;
  final List<ExtremumEvent> extrema;
  final double minCm;
  final double maxCm;

  _SignalPainter(this.samples, this.extrema, this.minCm, this.maxCm);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;

    final t0 = samples.first.dx;
    final span = max(samples.last.dx - t0, 1.0);
    final lo = minCm;
    final hi = max(maxCm, lo + 1);

    Offset map(double x, double cm) => Offset(
      (x - t0) / span * size.width,
      (size.height - ((cm - lo) / (hi - lo)) * size.height).clamp(
        0.0,
        size.height,
      ),
    );

    final path = Path();
    final first = map(samples.first.dx, samples.first.dy);
    path.moveTo(first.dx, first.dy);
    var prev = first;
    for (var i = 1; i < samples.length; i++) {
      final p = map(samples[i].dx, samples[i].dy);
      final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      prev = p;
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8A8A8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final nowX = samples.last.dx;
    for (final e in extrema) {
      if (e.timeSeconds < t0) continue;
      final alpha = (1 - (nowX - e.timeSeconds) / 2.0).clamp(0.0, 1.0);
      if (alpha <= 0) continue;
      canvas.drawCircle(
        map(e.timeSeconds, e.distanceCm),
        4,
        Paint()..color = const Color(0xFFFFA726).withValues(alpha: alpha),
      );
    }

    final last = map(samples.last.dx, samples.last.dy);
    _drawBall(canvas, last);
  }

  @override
  bool shouldRepaint(_SignalPainter old) => true;
}

// ============================================================
// Guided mode: target track + ball fixed in X
// ============================================================

class _GuidePainter extends CustomPainter {
  final GuideTrack guide;
  final double currentCm;
  final ValueListenable<double> position;

  /// Where the ball sits horizontally (fraction of width).
  static const ballXFrac = 0.28;

  /// Visible window: seconds of track behind and ahead of the ball.
  double get visibleSeconds => guide.visibleSeconds;

  _GuidePainter({
    required this.guide,
    required this.currentCm,
    required this.position,
  }) : super(repaint: position);

  @override
  void paint(Canvas canvas, Size size) {
    final lo = guide.minCm;
    final hi = max(guide.maxCm, lo + 1);
    final now = position.value;
    final ballX = size.width * ballXFrac;
    final span = visibleSeconds;
    final backSeconds = span * ballXFrac;
    final aheadSeconds = span - backSeconds;
    final tStart = now - backSeconds;

    double toX(double t) => (t - tStart) / span * size.width;
    double toY(double cm) =>
        (24 + (1 - (cm - lo) / (hi - lo)) * (size.height - 48)).clamp(
          24.0,
          size.height - 24.0,
        );

    // ---- Target track: thick gray band ----
    final path = Path();
    const steps = 240;
    for (var i = 0; i <= steps; i++) {
      final t = tStart + span * i / steps;
      final p = Offset(toX(t), toY(guide.targetCm(t)));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2E2E2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF7A7A7A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // ---- Markers on track extrema ----
    for (final e in guide.extremaAround(now, backSeconds, aheadSeconds)) {
      if (e.t <= now) continue;
      final x = toX(e.t);
      if (x < -20 || x > size.width + 20) continue;
      final p = Offset(x, toY(e.cm));
      // No blur here: cheap dots keep the repaint light.
      canvas.drawCircle(
        p,
        9,
        Paint()..color = const Color(0xFFFFA726).withValues(alpha: 0.4),
      );
      canvas.drawCircle(p, 5, Paint()..color = const Color(0xFFFFA726));
      break;
    }

    // ---- Ball: fixed X, Y follows the real distance ----
    final ball = Offset(ballX, toY(currentCm));
    _drawBall(canvas, ball);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => true;
}

void _drawBall(Canvas canvas, Offset center) {
  canvas.drawCircle(
    center,
    20,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
  );
  canvas.drawCircle(center, 10, Paint()..color = Colors.white);
}
