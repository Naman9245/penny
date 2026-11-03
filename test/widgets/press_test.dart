import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/theme/app_theme.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_pressable.dart';
import 'package:penny/widgets/pressable_area.dart';

// These run with animations on, as on a phone; the app's other tests turn
// them off, where taps act at once.
void main() {
  Future<void> show(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('a quick tap shows the button going down before it acts', (
    tester,
  ) async {
    var opened = 0;
    await show(tester, BrutalButton(label: 'Open', onPressed: () => opened++));
    final before = tester.getTopLeft(find.text('Open'));

    await tester.tap(find.text('Open'));
    // The sink starts on the next frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Down, and nothing opened yet.
    expect(tester.getTopLeft(find.text('Open')), isNot(before));
    expect(opened, 0);

    await tester.pump(const Duration(milliseconds: 60));
    expect(opened, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.getTopLeft(find.text('Open')), before);
  });

  testWidgets('a quick double tap opens once', (tester) async {
    var opened = 0;
    await show(tester, BrutalButton(label: 'Open', onPressed: () => opened++));
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(opened, 1);
  });

  testWidgets('keys that type act at once', (tester) async {
    var typed = 0;
    await show(
      tester,
      BrutalPressable(
        onPressed: () => typed++,
        waitForPress: false,
        child: const SizedBox(width: 60, height: 60, child: Text('1')),
      ),
    );
    await tester.tap(find.text('1'));
    await tester.pump();
    expect(typed, 1);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('with less motion, a tap acts at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    var opened = 0;
    await show(tester, BrutalButton(label: 'Open', onPressed: () => opened++));
    await tester.tap(find.text('Open'));
    await tester.pump();
    expect(opened, 1);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('a row darkens, a day shrinks, before either opens', (
    tester,
  ) async {
    var opened = 0;
    await show(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PressableArea(
            onTap: () => opened++,
            child: const SizedBox(width: 200, height: 40, child: Text('Row')),
          ),
          PressableArea(
            pressedScale: 0.9,
            onTap: () => opened++,
            child: const SizedBox(width: 40, height: 40, child: Text('3')),
          ),
        ],
      ),
    );

    await tester.tap(find.text('Row'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final tint = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('Row'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(
      (tint.foregroundDecoration! as BoxDecoration).color!.a,
      greaterThan(0),
    );
    expect(opened, 0);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, 1);

    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final scale = tester.widget<AnimatedScale>(
      find.ancestor(of: find.text('3'), matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, 0.9);
    expect(opened, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(opened, 2);
    await tester.pump(const Duration(milliseconds: 200));
  });
}
