import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('a combined entry says "2 in 1" and shows what it was made of', (
    tester,
  ) async {
    final now = DateTime.now();
    late String combined;
    final db = await pumpApp(
      tester,
      seed: (repo) async {
        final ids = [
          for (final (paise, hour) in [(667, 1), (1167, 2)])
            await repo.add(
              amountPaise: paise,
              type: TxnType.debit,
              categoryId: 'people',
              occurredAt: DateTime(now.year, now.month, now.day, hour),
              merchant: 'Ravi Kumar',
              payeeIsPerson: true,
            ),
        ];
        combined = (await repo.combine(ids))!;
      },
    );
    Future<List<Txn>> live() async => (await tester.runAsync(
      () => (db.select(db.txns)..where((t) => t.deletedAt.isNull())).get(),
    ))!;

    routerOf(tester).push('/txns');
    await tester.pumpAndSettle();
    expect(find.textContaining('2 in 1'), findsOneWidget);

    routerOf(tester).push('/txns/$combined');
    await tester.pumpAndSettle();
    final madeOf = find.byKey(const ValueKey('made-of'));
    await tester.scrollUntilVisible(
      madeOf,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: madeOf, matching: find.text('Made of 2 payments')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: madeOf, matching: find.text('Ravi Kumar')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: madeOf, matching: find.text('−₹6.67')),
      findsOneWidget,
    );

    final split = find.byKey(const ValueKey('split-apart'));
    await tester.ensureVisible(split);
    await tester.pumpAndSettle();
    await tester.tap(split);
    await tester.pumpAndSettle();
    expect(find.text('Split back into 2 payments'), findsOneWidget);
    expect(await live(), hasLength(2));

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await live()).single.id, combined);
    await closeApp(tester, db);
  });

  testWidgets('an entry never combined shows no parts', (tester) async {
    late String id;
    final db = await pumpApp(
      tester,
      seed: (repo) async => id = await repo.add(
        amountPaise: 25000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    routerOf(tester).push('/txns/$id');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('made-of')), findsNothing);
    await closeApp(tester, db);
  });
}
