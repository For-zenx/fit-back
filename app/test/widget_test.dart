import 'dart:async';
import 'dart:math';

import 'package:fitback/core/distance_source.dart';
import 'package:fitback/main.dart';
import 'package:fitback/ui/motion_wave.dart';
import 'package:fitback/ui/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestDistanceSource implements DistanceSource {
  final _controller = StreamController<DistanceSample>.broadcast(sync: true);

  @override
  Stream<DistanceSample> get stream => _controller.stream;

  void emit(double timeSeconds, double distanceCm) {
    _controller.add(DistanceSample(timeSeconds, distanceCm));
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  Future<void> close() => _controller.close();
}

void main() {
  testWidgets('app builds the session screen', (tester) async {
    await tester.pumpWidget(const FitBackApp());
    expect(find.text('REPS'), findsOneWidget);
    expect(find.text('SET'), findsOneWidget);
    expect(find.text('Terminar set'), findsOneWidget);
  });

  testWidgets('first rep calibrates without counting, then counts', (
    tester,
  ) async {
    final source = TestDistanceSource();
    await tester.pumpWidget(MaterialApp(home: SessionScreen(source: source)));
    expect(find.text('Haz una repetición para calibrar'), findsOneWidget);
    for (var i = 0; i < 50; i++) {
      final t = i / 20.0;
      source.emit(t, 30 + 10 * (1 - cos(2 * pi * t / 2)));
    }
    await tester.pump();
    expect(find.text('Haz una repetición para calibrar'), findsNothing);
    expect(find.text('0'), findsOneWidget);
    for (var i = 50; i < 170; i++) {
      final t = i / 20.0;
      source.emit(t, 30 + 10 * (1 - cos(2 * pi * t / 2)));
    }
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  testWidgets('rest freezes the distance, rep count, and set clock', (
    tester,
  ) async {
    final source = TestDistanceSource();
    await tester.pumpWidget(MaterialApp(home: SessionScreen(source: source)));
    for (var i = 0; i < 170; i++) {
      final t = i / 20.0;
      source.emit(t, 30 + 10 * (1 - cos(2 * pi * t / 2)));
    }
    await tester.pump(const Duration(seconds: 2));
    final distanceBefore = tester
        .widget<MotionWave>(find.byType(MotionWave))
        .currentCm;
    final clockBefore = find.text('00:02');
    expect(clockBefore, findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('Terminar set'));
    await tester.pump();
    for (var i = 170; i < 270; i++) {
      final t = i / 20.0;
      source.emit(t, 30 + 10 * (1 - cos(2 * pi * t / 2)));
    }
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('3'), findsOneWidget);
    expect(clockBefore, findsOneWidget);
    expect(
      tester.widget<MotionWave>(find.byType(MotionWave)).currentCm,
      distanceBefore,
    );
    await tester.tap(find.text('Siguiente set'));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });

  testWidgets('controls fit a narrow portrait screen', (tester) async {
    tester.view.physicalSize = const Size(337, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const FitBackApp());
    expect(tester.takeException(), isNull);
  });

  testWidgets('guide pauses after inactivity and resumes with movement', (
    tester,
  ) async {
    final source = TestDistanceSource();
    await tester.pumpWidget(MaterialApp(home: SessionScreen(source: source)));
    for (var i = 0; i < 50; i++) {
      final t = i / 20.0;
      source.emit(t, 30 + 10 * (1 - cos(2 * pi * t / 2)));
    }
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Pausado · muévete para continuar'), findsOneWidget);
    for (var i = 50; i < 65; i++) {
      source.emit(i / 20.0, 50);
    }
    await tester.pump();
    await tester.pump();
    expect(find.text('Pausado · muévete para continuar'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await source.close();
  });
}
