import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/penny_pose.dart';
import 'package:penny/widgets/penny_mascot.dart';

void main() {
  Future<void> show(WidgetTester tester, List<Widget> pennys) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Wrap(children: pennys)),
        ),
      );

  Matrix4 bounce(WidgetTester tester) => tester
      .widget<Transform>(find.byKey(const ValueKey('penny-bounce')))
      .transform;

  testWidgets('every mood and moment draws, big and small, as she moves', (
    tester,
  ) async {
    await show(tester, [
      for (final size in const [96.0, 30.0]) ...[
        for (final mood in PennyMood.values)
          PennyMascot(mood: mood, size: size),
        for (final pose in PennyPose.values)
          PennyMascot(pose: pose, size: size),
      ],
    ]);
    // Once round her whole loop.
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Penny, sad'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Penny, thinking'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Penny, with an idea'), findsNWidgets(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('she moves, unless told to keep still', (tester) async {
    await show(tester, [const PennyMascot()]);
    expect(tester.hasRunningAnimations, isTrue);

    await show(tester, [const PennyMascot(bob: false)]);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('she keeps still when the phone asks for less motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await show(tester, [const PennyMascot(mood: PennyMood.celebrating)]);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byKey(const ValueKey('penny-confetti')), findsNothing);

    await show(tester, [const PennyMascot(mood: PennyMood.sad)]);
    expect(bounce(tester), Matrix4.identity());
  });

  testWidgets('a new mood lands with a bounce, celebrating with confetti', (
    tester,
  ) async {
    await show(tester, [const PennyMascot(mood: PennyMood.worried)]);
    expect(bounce(tester), Matrix4.identity());
    expect(find.byKey(const ValueKey('penny-confetti')), findsNothing);

    await show(tester, [const PennyMascot(mood: PennyMood.celebrating)]);
    await tester.pump(const Duration(milliseconds: 100));
    expect(bounce(tester), isNot(Matrix4.identity()));
    expect(find.byKey(const ValueKey('penny-confetti')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(bounce(tester), Matrix4.identity());
    expect(find.byKey(const ValueKey('penny-confetti')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
