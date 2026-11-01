import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/widgets/pill_nav_bar.dart';

const _items = [
  PillNavItem(icon: Icons.home_rounded, label: 'Home'),
  PillNavItem(icon: Icons.pie_chart_rounded, label: 'Analysis'),
  PillNavItem(icon: Icons.flag_rounded, label: 'Goals'),
  PillNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar'),
];

/// The bar on its own, switching tabs the way the app shell does.
Widget _bar() {
  var index = 0;
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
        bottomNavigationBar: PillNavBar(
          items: _items,
          currentIndex: index,
          onSelect: (i) => setState(() => index = i),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('only the selected tab shows its label', (tester) async {
    await tester.pumpWidget(_bar());
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Goals'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Goals'));
    // Step through the slide a frame at a time: nothing may overflow while
    // the pill and the label are mid-way.
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('dragging the pill two tabs along selects that tab',
      (tester) async {
    await tester.pumpWidget(_bar());

    await tester.drag(find.bySemanticsLabel('Home'), const Offset(2 * 58, 0));
    await tester.pumpAndSettle();

    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('a short drag snaps back to the same tab', (tester) async {
    await tester.pumpWidget(_bar());

    await tester.drag(find.bySemanticsLabel('Home'), const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Analysis'), findsNothing);
  });

  testWidgets('a quick flick carries on to the next tab', (tester) async {
    await tester.pumpWidget(_bar());

    await tester.fling(find.bySemanticsLabel('Home'), const Offset(60, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Analysis'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('switching settles at a large text size', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_bar());

    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsOneWidget);
  });
}
