import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/pill_nav_bar.dart';

const _items = [
  PillNavItem(icon: Icons.home_rounded, label: 'Home'),
  PillNavItem(icon: Icons.pie_chart_rounded, label: 'Analysis'),
  PillNavItem(icon: Icons.flag_rounded, label: 'Goals'),
  PillNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar'),
];

/// The bar on its own, switching tabs the way the app shell does, with
/// Add beside it when [withAdd].
Widget _bar({int start = 0, bool withAdd = false}) {
  var index = start;
  return MaterialApp(
    home: StatefulBuilder(
      builder: (context, setState) => Scaffold(
        bottomNavigationBar: PillNavBar(
          items: _items,
          currentIndex: index,
          onSelect: (i) => setState(() => index = i),
          trailing: withAdd
              ? (size) => BrutalIconButton(
                  icon: Icons.add_rounded,
                  semanticLabel: 'Add',
                  color: AppColors.yellow,
                  size: size,
                  onPressed: () {},
                )
              : null,
        ),
      ),
    ),
  );
}

/// A phone [width] dp wide.
void _phone(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  // The labels in Penny's own font, so their widths are the real ones.
  setUpAll(() async {
    final font = FontLoader(AppText.bodyFamily)
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/DMSans-Bold.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
  });

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

  testWidgets('dragging the pill two tabs along selects that tab', (
    tester,
  ) async {
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

    await tester.fling(
      find.bySemanticsLabel('Home'),
      const Offset(60, 0),
      1000,
    );
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

  testWidgets('with Add beside it, a roomy phone keeps full-size tabs', (
    tester,
  ) async {
    _phone(tester, 412);
    await tester.pumpWidget(_bar(withAdd: true));

    expect(tester.getSize(find.bySemanticsLabel('Goals')), const Size(52, 52));
    expect(tester.getSize(find.bySemanticsLabel('Add')), const Size(64, 64));
  });

  testWidgets('at 360 wide and a large text size, four tabs and Add fit', (
    tester,
  ) async {
    _phone(tester, 360);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_bar(start: 3, withAdd: true));

    // The circles shrink to make room, and Add stays as tall as the bar.
    final circle = tester.getSize(find.bySemanticsLabel('Goals'));
    expect(circle.width, lessThan(52));
    expect(circle.height, circle.width);
    final add = tester.getRect(find.bySemanticsLabel('Add'));
    expect(add.height, circle.height + 12);
    expect(add.right, lessThanOrEqualTo(360));

    // The longest label shows whole: as wide as it is laid out on its own.
    final label = tester.renderObject<RenderParagraph>(find.text('Calendar'));
    expect(
      label.size.width,
      moreOrLessEquals(label.getMaxIntrinsicWidth(double.infinity)),
    );
    expect(
      tester.getRect(find.text('Calendar')).right,
      lessThanOrEqualTo(tester.getRect(find.bySemanticsLabel('Calendar')).right),
    );
  });
}
