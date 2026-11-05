import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/csv_export.dart';

import '../helpers/app_harness.dart';

void main() {
  testWidgets('Export entries hands a CSV of every entry to the share menu', (
    tester,
  ) async {
    final shared = <(String, String)>[];
    final db = await pumpApp(
      tester,
      seed: (repo) => repo.add(
        amountPaise: 2000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: DateTime.now(),
        merchant: 'Chai point',
      ),
      overrides: [
        shareFileProvider.overrideWithValue(
          (name, bytes) async => shared.add((name, utf8.decode(bytes))),
        ),
      ],
    );
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tapInView(tester, find.byKey(const ValueKey('export-entries')));

    final (name, csv) = shared.single;
    expect(name, startsWith('penny-entries-'));
    expect(name, endsWith('.csv'));
    final rows = csv.substring(1).trim().split('\r\n');
    expect(rows, hasLength(2));
    expect(rows.last, contains(',Spent,Food,Chai point,20.00,,Typed'));
    await closeApp(tester, db);
  });

  testWidgets('Goals says goal money still counts as left', (tester) async {
    final db = await pumpApp(
      tester,
      seedDb: (db) => GoalRepository(db).add(
        title: 'Delhi trip',
        targetPaise: 1500000,
        deadline: DateTime.now().add(const Duration(days: 90)),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Goals'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goals-left-note')), findsOneWidget);
    await closeApp(tester, db);
  });
}
