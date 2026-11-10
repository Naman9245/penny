import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/add_txn/category_order.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/txn_factory.dart';

void main() {
  final day = DateTime(2026, 11, 1);
  List<String> ids(List<Category> categories) => [
    for (final category in categories) category.id,
  ];

  test('with nothing counted, the tiles keep their order', () {
    final tiles = categoriesFor(TxnType.debit);
    expect(ids(mostUsedFirst(tiles, CategoryUses.none)), ids(tiles));
    expect(ids(mostUsedFirst(tiles, CategoryUses(const []))), ids(tiles));
  });

  test('the most used come first, and ties keep their order', () {
    final tiles = categoriesFor(TxnType.debit);
    final uses = CategoryUses([
      for (var i = 0; i < 3; i++) txn(50, day, categoryId: 'fun'),
      // Rent and travel tie, so travel stays ahead, as in the grid.
      txn(9000, day, categoryId: 'rent'),
      txn(30, day, categoryId: 'travel'),
      txn(500, day, categoryId: 'stocks'),
    ]);

    final ordered = ids(mostUsedFirst(tiles, uses));
    expect(ordered.take(5), ['fun', 'travel', 'rent', 'stocks', 'food']);
    // Everything else keeps its place, with Other still last.
    expect(ordered.skip(5), [
      for (final id in ids(tiles))
        if (!{'fun', 'travel', 'rent', 'stocks', 'food'}.contains(id)) id,
    ]);
    expect(ordered.last, 'other');
    expect(ordered, hasLength(tiles.length));
  });

  test('money in counts for income, not for the spend it paid back', () {
    final uses = CategoryUses([
      txn(200, day, type: TxnType.credit, categoryId: 'freelance'),
      txn(200, day, type: TxnType.credit, categoryId: 'freelance'),
      // A friend's share of a dinner, three times over.
      for (var i = 0; i < 3; i++)
        txn(300, day, type: TxnType.credit, categoryId: 'shopping'),
      txn(40, day, categoryId: 'groceries'),
    ]);

    final spends = ids(mostUsedFirst(categoriesFor(TxnType.debit), uses));
    expect(spends.take(3), ['groceries', 'food', 'travel']);
    expect(spends.indexOf('shopping'), 4);

    final income = ids(mostUsedFirst(categoriesFor(TxnType.credit), uses));
    expect(income.first, 'freelance');
    expect(income.skip(1), [
      for (final id in ids(incomeCategories))
        if (id != 'freelance') id,
    ]);
  });

  test('for a payback, what came back most goes first, then what was spent '
      'most', () {
    final uses = CategoryUses([
      for (var i = 0; i < 2; i++)
        txn(300, day, type: TxnType.credit, categoryId: 'travel'),
      txn(300, day, type: TxnType.credit, categoryId: 'fun'),
      for (var i = 0; i < 4; i++) txn(50, day, categoryId: 'groceries'),
      txn(50, day, categoryId: 'fun'),
      for (var i = 0; i < 3; i++) txn(50, day, categoryId: 'health'),
    ]);

    final ordered = ids(mostUsedFirst(spendCategories, uses, paybacks: true));
    // Came back twice, then once, then spent on four and three times.
    expect(ordered.take(5), ['travel', 'fun', 'groceries', 'health', 'food']);
    expect(ordered.last, 'other');
    expect(ordered, hasLength(spendCategories.length));
  });
}
