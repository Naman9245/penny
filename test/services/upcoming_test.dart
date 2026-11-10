import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/upcoming_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/sms_parser.dart';
import 'package:penny/services/upcoming_math.dart';

import '../helpers/txn_factory.dart';

void main() {
  // All made up.
  final now = DateTime(2026, 11, 10, 12);
  final today = DateTime(2026, 11, 10);

  group('a message about a payment to come', () {
    test('how much, the day and to whom', () {
      final read = parseUpcoming(
        'Rs.1,499.00 will be debited from A/c XX4821 on 15-11-26 for '
        'NETFLIX autopay.',
        now: now,
      )!;
      expect(read.amountPaise, 149900);
      expect(read.dueOn, DateTime(2026, 11, 15));
      expect(read.payee, 'Netflix');
      expect(read.categoryId, 'subscriptions');
    });

    test('an EMI due goes as an EMI', () {
      final read = parseUpcoming(
        'Your EMI of Rs.5,000.00 for loan A/c XX8812 is due on 05-12-26.',
        now: now,
      )!;
      expect(read.amountPaise, 500000);
      expect(read.dueOn, DateTime(2026, 12, 5));
      expect(read.categoryId, 'emi');
    });

    test('none without an amount, a day ahead, or for a mandate', () {
      expect(parseUpcoming('Your bill is due on 15-11-26.', now: now), isNull);
      expect(parseUpcoming('Rs.500 is due. Pay soon.', now: now), isNull);
      // Past days and days far off aren't believed.
      expect(parseUpcoming('Rs.500 was due on 01-10-26.', now: now), isNull);
      expect(
        parseUpcoming(
          'Mandate of Rs.1,000 registered successfully for SIP.',
          now: now,
        ),
        isNull,
      );
      // A payment made isn't one to come.
      expect(
        parseUpcoming(
          'Rs.250.00 debited from A/c XX4821 to SWIGGY on 10-11-26.',
          now: now,
        ),
        isNull,
      );
    });
  });

  group('what the Coming up card shows', () {
    late AppDatabase db;
    late UpcomingRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = UpcomingRepository(db, clock: () => now);
    });
    tearDown(() => db.close());

    UpcomingRead due(int rupees, DateTime on, String key) => (
      amountPaise: rupees * 100,
      dueOn: on,
      payee: 'Netflix',
      categoryId: 'subscriptions',
      dedupeKey: key,
    );

    test('soonest first, within a month, kept once', () async {
      await repo.keep(due(649, DateTime(2026, 11, 20), 'b'));
      await repo.keep(due(5000, DateTime(2026, 11, 12), 'a'));
      await repo.keep(due(5000, DateTime(2026, 11, 12), 'a'));
      await repo.keep(due(999, DateTime(2026, 12, 25), 'far'));
      final kept = await repo.watchFrom(today).first;
      final shown = comingUp(kept, const [], today);
      expect([for (final d in shown) d.dedupeKey], ['a', 'b']);
    });

    test('paid already, or taken off, it goes', () async {
      await repo.keep(due(649, DateTime(2026, 11, 12), 'paid'));
      await repo.keep(due(500, DateTime(2026, 11, 14), 'off'));
      await repo.keep(due(300, DateTime(2026, 11, 15), 'left'));
      await repo.dismiss('off');
      final kept = await repo.watchFrom(today).first;
      final shown = comingUp(kept, [
        txn(649, DateTime(2026, 11, 11, 9)),
        // Money in of the same amount isn't paying it.
        txn(300, DateTime(2026, 11, 15), type: TxnType.credit),
      ], today);
      expect([for (final d in shown) d.dedupeKey], ['left']);
    });

    test('a late one shows for three days after its day', () async {
      await repo.keep(due(649, DateTime(2026, 11, 8), 'late'));
      await repo.keep(due(649, DateTime(2026, 11, 6), 'gone'));
      final kept = await repo.watchFrom(DateTime(2026, 11, 1)).first;
      expect(
        [for (final d in comingUp(kept, const [], today)) d.dedupeKey],
        ['late'],
      );
    });
  });
}
