// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

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
}
