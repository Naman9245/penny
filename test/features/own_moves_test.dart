import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/sms_parser.dart';

import '../helpers/app_harness.dart';

// All made up, digits included.
const walletOut =
    'Rs.2000 Deducted\nFrom PayZapp Wallet\nOn 05-11-2026 14:30:12\n'
    'Bal: Rs.575.88\nNot you? Report: https://1.hdfc.bank.in/HDFCBK/s/ab12cd34 '
    'or SMS BLOCKPZW to 5676712';
const bankIn =
    'Credit Alert!\nRs.2000.00 credited to HDFC Bank A/c XX4821 on 05-11-26 '
    'from VPA *1234@pzw (UPI 175566436892)';

/// [text] saved as an older Penny did: as money in or out.
Future<String> savedBefore(
  AppDatabase db,
  String sender,
  String text,
  DateTime when,
) async {
  final read = parseSms(text, now: when) as SmsTxn;
  final id = await TxnRepository(db).add(
    amountPaise: read.amountPaise,
    type: read.type,
    categoryId: read.type == TxnType.debit ? 'other' : 'from_people',
    occurredAt: when,
    source: TxnSource.sms,
    dedupeKey: read.dedupeKey,
    payeeIsPerson: read.payeeIsPerson,
  );
  await CaptureRepository(db)
      .recordSaved(read, app: 'sms', at: when, entryId: id, sender: sender);
  return id;
}

void main() {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));

  Future<void> aMove(AppDatabase db) async {
    await savedBefore(db, 'JM-HDFCBN-S', walletOut, yesterday);
    await savedBefore(
      db,
      'JX-HDFCBK-S',
      bankIn,
      yesterday.add(const Duration(minutes: 1)),
    );
  }

  Future<List<Txn>> live(WidgetTester tester, AppDatabase db) async =>
      (await tester.runAsync(
        () => (db.select(db.txns)..where((t) => t.deletedAt.isNull())).get(),
      ))!;

  Future<Finder> offer(WidgetTester tester) async {
    final card = find.byKey(const ValueKey('own-move-offer'));
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    return card;
  }

  testWidgets('Home offers to take out a move saved as two entries', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: aMove);
    final card = await offer(tester);
    expect(
      find.descendant(
        of: card,
        matching: find.textContaining(
          '₹2,000 went from your wallet to your bank yesterday',
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('own-move-remove')));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(await live(tester, db), isEmpty);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await live(tester, db), hasLength(2));
    await closeApp(tester, db);
  });

  testWidgets('Keep them: Penny never asks about that move again', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: aMove);
    final card = await offer(tester);
    await tester.tap(find.byKey(const ValueKey('own-move-keep')));
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(await live(tester, db), hasLength(2));
    await closeApp(tester, db);
  });

  testWidgets('"This was my own money" on an entry takes out both halves', (
    tester,
  ) async {
    late String into;
    final db = await pumpApp(
      tester,
      seedDb: (db) async {
        await savedBefore(db, 'JM-HDFCBN-S', walletOut, yesterday);
        into = await savedBefore(
          db,
          'JX-HDFCBK-S',
          bankIn,
          yesterday.add(const Duration(minutes: 1)),
        );
      },
    );
    routerOf(tester).push('/txns/$into');
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('own-money'));
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
      find.text('Took it out, and its other half: your own money moving'),
      findsOneWidget,
    );
    expect(await live(tester, db), isEmpty);
    await closeApp(tester, db);
  });

  testWidgets('a typed entry has no "This was my own money"', (tester) async {
    late String typed;
    final db = await pumpApp(
      tester,
      seed: (repo) async => typed = await repo.add(
        amountPaise: 25000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: yesterday,
      ),
    );
    routerOf(tester).push('/txns/$typed');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('own-money')), findsNothing);
    await closeApp(tester, db);
  });
}
