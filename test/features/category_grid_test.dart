import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/theme/app_theme.dart';
import 'package:penny/features/add_txn/category_grid.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/widgets/category_avatar.dart';

/// Loads the labels' own font, so they're as wide as on a phone. Tests
/// otherwise draw every letter as a square.
Future<void> loadLabelFont() async {
  final bytes = File('assets/fonts/DMSans-Medium.ttf').readAsBytesSync();
  await (FontLoader(
    'DMSans',
  )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
}

/// The grid on a phone [phoneWidth] wide, inside the Add screen's 16 px
/// sides, with text at [textScale].
Future<void> pumpGrid(
  WidgetTester tester,
  List<Category> categories, {
  required double phoneWidth,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: phoneWidth - 32,
              child: CategoryGrid(categories: categories, onTap: (_) {}),
            ),
          ),
        ),
      ),
    ),
  );
}

/// How many tiles share the first row.
int firstRow(WidgetTester tester) {
  final avatars = find.byType(CategoryAvatar);
  final top = tester.getTopLeft(avatars.first).dy;
  var count = 0;
  while (count < avatars.evaluate().length &&
      tester.getTopLeft(avatars.at(count)).dy == top) {
    count++;
  }
  return count;
}

void main() {
  testWidgets('four tiles a row on a phone, five when there is room', (
    tester,
  ) async {
    await loadLabelFont();
    final spends = categoriesFor(TxnType.debit);

    await pumpGrid(tester, spends, phoneWidth: 393);
    expect(firstRow(tester), 4);

    await pumpGrid(tester, spends, phoneWidth: 480);
    expect(firstRow(tester), 5);

    // Smaller text makes room for five on a phone too.
    await pumpGrid(tester, spends, phoneWidth: 412, textScale: 0.85);
    expect(firstRow(tester), 5);

    // Bigger text, fewer to a row.
    await pumpGrid(tester, spends, phoneWidth: 393, textScale: 1.3);
    expect(firstRow(tester), 3);

    // Never more than five, however wide.
    await pumpGrid(tester, spends, phoneWidth: 800);
    expect(firstRow(tester), 5);
  });

  testWidgets('no label breaks mid-word or gets cut short', (tester) async {
    await loadLabelFont();
    for (final type in TxnType.values) {
      final categories = categoriesFor(type);
      for (final phoneWidth in const <double>[320, 360, 393, 412, 480, 600]) {
        for (final textScale in const [0.85, 1.0, 1.15, 1.3]) {
          await pumpGrid(
            tester,
            categories,
            phoneWidth: phoneWidth,
            textScale: textScale,
          );
          final at = '${phoneWidth.round()} wide, text ×$textScale';
          for (final category in categories) {
            final label = category.label;
            final paragraph = tester.renderObject<RenderParagraph>(
              find.text(label),
            );
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '"$label" is cut short at $at',
            );
            // A line may break at a space, or after a slash as in
            // Refund/cashback, but never inside a word.
            for (final word in RegExp(r'[^\s/]+/?').allMatches(label)) {
              final lines = {
                for (final box in paragraph.getBoxesForSelection(
                  TextSelection(baseOffset: word.start, extentOffset: word.end),
                ))
                  box.top,
              };
              expect(
                lines,
                hasLength(1),
                reason: '"${word[0]}" of "$label" breaks at $at',
              );
            }
          }
        }
      }
    }
  });
}
