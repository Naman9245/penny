import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/combine_math.dart';

import '../helpers/txn_factory.dart';

void main() {
  // All made up.
  final today = DateTime(2026, 11, 15);
  DateTime on(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);

  group('what combining makes', () {
    test('the total, on the latest one, as the first one is', () {
      final combined = combinationOf([
        txn(
          7,
          on(15, 13),
          merchant: 'Ravi Kumar',
          categoryId: 'people',
          payeeIsPerson: true,
        ),
        txn(
          12,
          on(15, 9),
          merchant: 'Ravi Kumar',
          categoryId: 'people',
          payeeIsPerson: true,
          source: TxnSource.sms,
        ),
      ])!;
      expect(combined.amountPaise, 1900);
      expect(combined.type, TxnType.debit);
      expect(combined.occurredAt, on(15, 13));
      expect(combined.merchant, 'Ravi Kumar');
      expect(combined.categoryId, 'people');
      expect(combined.payeeIsPerson, isTrue);
      // The first one's, as it came first.
      expect(combined.source, TxnSource.sms);
    });

    test('not for one alone, or for money of different kinds', () {
      expect(combinationOf([txn(10, on(15))]), isNull);
      expect(
        combinationOf([
          txn(10, on(15)),
          txn(10, on(15), type: TxnType.credit, categoryId: 'salary'),
        ]),
        isNull,
      );
      // Spending and investing are both money out, but don't add up.
      expect(
        combinationOf([txn(10, on(15)), txn(10, on(15), categoryId: 'invest')]),
        isNull,
      );
    });
  });

  group('what Penny offers to combine', () {
    test('one payee, two or more payments on one day, newest day first', () {
      final offers = combineOffers(
        [
          txn(7, on(15, 9), merchant: 'Ravi Kumar'),
          txn(12, on(15, 13), merchant: 'RAVI KUMAR'),
          txn(50, on(13, 9), merchant: 'Swiggy'),
          txn(60, on(13, 20), merchant: 'Swiggy'),
          // Not the same day.
          txn(30, on(14), merchant: 'Namma Metro'),
          txn(30, on(15), merchant: 'Namma Metro'),
          // Money in isn't spending; no name, nothing to go by.
          txn(100, on(15), type: TxnType.credit, merchant: 'Amit'),
          txn(100, on(15), type: TxnType.credit, merchant: 'Amit'),
          txn(5, on(15)),
          txn(5, on(15)),
        ],
        today,
        const {},
      );
      expect([for (final o in offers) o.payee], ['Ravi Kumar', 'Swiggy']);
      expect(offers.first.totalPaise, 1900);
      expect(offers.first.txns, hasLength(2));
      expect(offers.first.day, DateTime(2026, 11, 15));
    });

    test('not once told "Not now", nor from before the last week', () {
      final pair = [
        txn(7, on(15, 9), merchant: 'Ravi Kumar'),
        txn(12, on(15, 13), merchant: 'Ravi Kumar'),
      ];
      final key = combineOffers(pair, today, const {}).single.key;
      expect(combineOffers(pair, today, {key}), isEmpty);
      expect(
        combineOffers(
          [
            txn(7, on(5, 9), merchant: 'Ravi Kumar'),
            txn(12, on(5, 13), merchant: 'Ravi Kumar'),
          ],
          today,
          const {},
        ),
        isEmpty,
      );
    });
  });

  group('combining entries', () {
    late AppDatabase db;
    late TxnRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = TxnRepository(db, clock: () => on(15, 14));
    });
    tearDown(() => db.close());

    Future<String> add(int paise, DateTime at, {String? key}) => repo.add(
      amountPaise: paise,
      type: TxnType.debit,
      categoryId: 'people',
      occurredAt: at,
      merchant: 'Ravi Kumar',
      source: TxnSource.sms,
      dedupeKey: key,
      payeeIsPerson: true,
    );

    Future<List<Txn>> live() =>
        (db.select(db.txns)..where((t) => t.deletedAt.isNull())).get();

    test('makes one for the total, and Undo brings them back', () async {
      final a = await add(667, on(15, 9), key: 'sms-a');
      final b = await add(1167, on(15, 13), key: 'sms-b');
      final combined = (await repo.combine([a, b]))!;

      final one = (await live()).single;
      expect(one.id, combined);
      expect(one.amountPaise, 1834);
      expect(one.occurredAt, on(15, 13));
      expect(one.merchant, 'Ravi Kumar');
      expect(one.dirty, isTrue, reason: 'backup carries it');
      // The originals are deleted, so they sync as deleted, and their SMS
      // are known by them still.
      final gone = await db.select(db.txns).get();
      expect(gone.where((t) => t.deletedAt != null), hasLength(2));

      await repo.uncombine(combined, [a, b]);
      expect({for (final t in await live()) t.id}, {a, b});
    });

    test("leaves entries alone that can't be combined", () async {
      final a = await add(667, on(15, 9));
      final paid = await repo.add(
        amountPaise: 500,
        type: TxnType.credit,
        categoryId: 'salary',
        occurredAt: on(15),
      );
      expect(await repo.combine([a, paid]), isNull);
      expect(await live(), hasLength(2));
    });
  });
}
