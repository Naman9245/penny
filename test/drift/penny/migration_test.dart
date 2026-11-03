// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // A v1 entry keeps every field and gains an empty SMS fingerprint.
  test('migration from v1 to v2 does not corrupt data', () async {
    const id = '0192f0c0-0000-7000-8000-000000000001';
    const at = 1793500000; // Seconds since the epoch, as v1 stored dates.
    final oldTxnsData = <v1.TxnsData>[
      const v1.TxnsData(
        id: id,
        amountPaise: 25000,
        type: 'debit',
        categoryId: 'food',
        merchant: 'Swiggy',
        occurredAt: at,
        source: 'manual',
        createdAt: at,
        updatedAt: at,
      ),
    ];
    final expectedNewTxnsData = <v2.TxnsData>[
      const v2.TxnsData(
        id: id,
        amountPaise: 25000,
        type: 'debit',
        categoryId: 'food',
        merchant: 'Swiggy',
        occurredAt: at,
        source: 'manual',
        createdAt: at,
        updatedAt: at,
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.txns, oldTxnsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewTxnsData, await newDb.select(newDb.txns).get());
      },
    );
  });

  // A v2 import keeps every field; whether its payee is a person stays
  // unknown, and there are no reports yet.
  test('migration from v2 to v3 does not corrupt data', () async {
    const id = '0192f0c0-0000-7000-8000-000000000002';
    const at = 1793500000;
    final oldTxnsData = <v2.TxnsData>[
      const v2.TxnsData(
        id: id,
        amountPaise: 34900,
        type: 'debit',
        categoryId: 'food',
        merchant: 'Swiggy',
        occurredAt: at,
        source: 'share',
        createdAt: at,
        updatedAt: at,
        dedupeKey: 'abc',
      ),
    ];
    final expectedNewTxnsData = <v3.TxnsData>[
      const v3.TxnsData(
        id: id,
        amountPaise: 34900,
        type: 'debit',
        categoryId: 'food',
        merchant: 'Swiggy',
        occurredAt: at,
        source: 'share',
        createdAt: at,
        updatedAt: at,
        dedupeKey: 'abc',
      ),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 3,
      createOld: v2.DatabaseAtV2.new,
      createNew: v3.DatabaseAtV3.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.txns, oldTxnsData);
      },
      validateItems: (newDb) async {
        expect(expectedNewTxnsData, await newDb.select(newDb.txns).get());
        expect(await newDb.select(newDb.insights).get(), isEmpty);
      },
    );
  });

  // Entries and Penny's reports carry over; My needs and the chat start
  // empty.
  test('migration from v3 to v4 does not corrupt data', () async {
    const id = '0192f0c0-0000-7000-8000-000000000003';
    const at = 1793500000;
    const txn = v3.TxnsData(
      id: id,
      amountPaise: 34900,
      type: 'debit',
      categoryId: 'food',
      merchant: 'Swiggy',
      occurredAt: at,
      source: 'share',
      tag: 'wasteful',
      createdAt: at,
      updatedAt: at,
      dedupeKey: 'abc',
      payeeIsPerson: 0,
    );
    const insight = v3.InsightsData(
      month: '2026-10',
      inputHash: 'hash',
      groupKeys: '{"s1":["shop|food|swiggy"]}',
      answer: '{"tags":{"s1":"wasteful"}}',
      model: 'gemini-3.5-flash-lite',
      createdAt: at,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 3,
      newVersion: 4,
      createOld: v3.DatabaseAtV3.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.txns, [txn]);
        batch.insertAll(oldDb.insights, [insight]);
      },
      validateItems: (newDb) async {
        final txns = await newDb.select(newDb.txns).get();
        expect(txns.single.toJson(), txn.toJson());
        final insights = await newDb.select(newDb.insights).get();
        expect(insights.single.toJson(), insight.toJson());
        expect(await newDb.select(newDb.tagRules).get(), isEmpty);
        expect(await newDb.select(newDb.prefs).get(), isEmpty);
        expect(await newDb.select(newDb.chatMessages).get(), isEmpty);
      },
    );
  });

  // Entries, My needs, the note and the chat carry over; the budget and
  // goals start empty.
  test('migration from v4 to v5 does not corrupt data', () async {
    const at = 1793500000;
    const txn = v4.TxnsData(
      id: '0192f0c0-0000-7000-8000-000000000004',
      amountPaise: 34900,
      type: 'debit',
      categoryId: 'food',
      merchant: 'Swiggy',
      occurredAt: at,
      source: 'manual',
      createdAt: at,
      updatedAt: at,
    );
    const rule = v4.TagRulesData(
      id: '0192f0c0-0000-7000-8000-000000000005',
      kind: 'shop',
      ruleKey: 'swiggy',
      tag: 'wasteful',
      createdAt: at,
      updatedAt: at,
    );
    const note = v4.PrefsData(
      name: 'penny_note',
      value: 'Student in a PG',
      updatedAt: at,
    );
    const message = v4.ChatMessagesData(
      id: '0192f0c0-0000-7000-8000-000000000006',
      role: 'user',
      body: 'How can I save?',
      createdAt: at,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 4,
      newVersion: 5,
      createOld: v4.DatabaseAtV4.new,
      createNew: v5.DatabaseAtV5.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.txns, [txn]);
        batch.insertAll(oldDb.tagRules, [rule]);
        batch.insertAll(oldDb.prefs, [note]);
        batch.insertAll(oldDb.chatMessages, [message]);
      },
      validateItems: (newDb) async {
        final txns = await newDb.select(newDb.txns).get();
        expect(txns.single.toJson(), txn.toJson());
        final rules = await newDb.select(newDb.tagRules).get();
        expect(rules.single.toJson(), rule.toJson());
        final prefs = await newDb.select(newDb.prefs).get();
        expect(prefs.single.toJson(), note.toJson());
        final messages = await newDb.select(newDb.chatMessages).get();
        expect(messages.single.toJson(), message.toJson());
        expect(await newDb.select(newDb.budgets).get(), isEmpty);
        expect(await newDb.select(newDb.goals).get(), isEmpty);
        expect(await newDb.select(newDb.goalDeposits).get(), isEmpty);
        expect(await newDb.select(newDb.goalPlans).get(), isEmpty);
      },
    );
  });

  // Everything carries over, marked to send on the first sync; the chat,
  // which never syncs, is untouched, and nothing has synced yet.
  test('migration from v5 to v6 does not corrupt data', () async {
    const at = 1793500000;
    const txn = v5.TxnsData(
      id: '0192f0c0-0000-7000-8000-000000000007',
      amountPaise: 34900,
      type: 'debit',
      categoryId: 'food',
      merchant: 'Swiggy',
      occurredAt: at,
      source: 'manual',
      createdAt: at,
      updatedAt: at,
    );
    const budget = v5.BudgetsData(
      id: '0192f0c0-0000-7000-8000-000000000008',
      budgetKey: 'food',
      amountPaise: 500000,
      createdAt: at,
      updatedAt: at,
    );
    const note = v5.PrefsData(
      name: 'penny_note',
      value: 'Student in a PG',
      updatedAt: at,
    );
    const message = v5.ChatMessagesData(
      id: '0192f0c0-0000-7000-8000-000000000009',
      role: 'user',
      body: 'How can I save?',
      createdAt: at,
    );

    await verifier.testWithDataIntegrity(
      oldVersion: 5,
      newVersion: 6,
      createOld: v5.DatabaseAtV5.new,
      createNew: v6.DatabaseAtV6.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.txns, [txn]);
        batch.insertAll(oldDb.budgets, [budget]);
        batch.insertAll(oldDb.prefs, [note]);
        batch.insertAll(oldDb.chatMessages, [message]);
      },
      validateItems: (newDb) async {
        final txns = await newDb.select(newDb.txns).get();
        expect(txns.single.toJson(), {...txn.toJson(), 'dirty': 1});
        final budgets = await newDb.select(newDb.budgets).get();
        expect(budgets.single.toJson(), {...budget.toJson(), 'dirty': 1});
        final prefs = await newDb.select(newDb.prefs).get();
        expect(prefs.single.toJson(), {...note.toJson(), 'dirty': 1});
        final messages = await newDb.select(newDb.chatMessages).get();
        expect(messages.single.toJson(), message.toJson());
        expect(await newDb.select(newDb.syncCursors).get(), isEmpty);
      },
    );
  });
}
