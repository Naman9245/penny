import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/autopay_math.dart';

Autopay autopay({
  String id = 'a1',
  String name = 'Spotify',
  int paise = 13900,
  AutopayEvery every = AutopayEvery.monthly,
  DateTime? nextOn,
  DateTime? lastPaidOn,
  bool paused = false,
  DateTime? endedAt,
}) => Autopay(
  id: id,
  name: name,
  amountPaise: paise,
  every: every,
  nextOn: nextOn,
  lastPaidOn: lastPaidOn,
  paused: paused,
  endedAt: endedAt,
  fromMessage: false,
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
  dirty: true,
);

void main() {
  group('the same autopay', () {
    test('a bank\'s long name and the short one', () {
      expect(sameAutopay('SPOTIFY INDIA PVT LTD', 'Spotify'), isTrue);
      expect(sameAutopay('Groww Invest Tech Pvt Ltd', 'Groww'), isTrue);
      expect(autopayKey('SPOTIFY INDIA PVT LTD'), 'spotify');
    });

    test('two from one company are two', () {
      expect(sameAutopay('Google Play', 'Google One'), isFalse);
      expect(sameAutopay('Netflix', 'Spotify'), isFalse);
    });
  });

  group('next days', () {
    test('a month on, the last day of a shorter month', () {
      expect(
        nextAfter(DateTime(2027, 1, 31), AutopayEvery.monthly),
        DateTime(2027, 2, 28),
      );
      expect(
        nextAfter(DateTime(2026, 11, 23), AutopayEvery.monthly),
        DateTime(2026, 12, 23),
      );
    });

    test('a week, three months and a year on', () {
      final on = DateTime(2026, 11, 23);
      expect(nextAfter(on, AutopayEvery.weekly), DateTime(2026, 11, 30));
      expect(nextAfter(on, AutopayEvery.quarterly), DateTime(2027, 2, 23));
      expect(nextAfter(on, AutopayEvery.yearly), DateTime(2027, 11, 23));
    });

    test('a day gone by without it moves on, a late one stays', () {
      final today = DateTime(2026, 11, 18);
      expect(
        dueOn(autopay(nextOn: DateTime(2026, 10, 10)), today),
        DateTime(2026, 12, 10),
      );
      // Two days late: maybe it's still going out.
      expect(
        dueOn(autopay(nextOn: DateTime(2026, 11, 16)), today),
        DateTime(2026, 11, 16),
      );
      expect(dueOn(autopay(), today), isNull);
    });
  });

  test('a month of autopays: weekly ones 52 times a year', () {
    expect(
      monthlyPaise([
        autopay(id: 'a', paise: 13900),
        autopay(id: 'b', paise: 120000, every: AutopayEvery.yearly),
        autopay(id: 'c', paise: 1200, every: AutopayEvery.weekly),
        autopay(id: 'd', paise: 50000, paused: true),
        autopay(id: 'e', paise: 50000, endedAt: DateTime(2026, 11, 2)),
      ]),
      13900 + 10000 + 5200,
    );
  });

  group('reminders', () {
    final due = DateTime(2026, 11, 23);

    test('5 days and 1 day before, at 10 in the morning', () {
      final reminders = remindersFor([
        autopay(nextOn: due),
      ], DateTime(2026, 11, 18, 9));
      expect(
        [for (final r in reminders) r.at],
        [DateTime(2026, 11, 18, 10), DateTime(2026, 11, 22, 10)],
      );
      expect(reminders.first.title, 'Psst! Spotify in 5 days');
      expect(
        reminders.first.text,
        '₹139 goes out on Monday, 23 Nov. Keep a little extra in the bank 🎧',
      );
      expect(reminders.last.title, 'Spotify autopay tomorrow');
    });

    test('ones already past are left out', () {
      final reminders = remindersFor([
        autopay(nextOn: due),
      ], DateTime(2026, 11, 18, 11));
      expect(reminders.single.at, DateTime(2026, 11, 22, 10));
    });

    test('none for one paused, cancelled or without a day', () {
      final now = DateTime(2026, 11, 18, 9);
      expect(
        remindersFor([
          autopay(nextOn: due, paused: true),
          autopay(id: 'b', nextOn: due, endedAt: DateTime(2026, 11, 1)),
          autopay(id: 'c'),
        ], now),
        isEmpty,
      );
    });

    test('the same reminder keeps its id', () {
      final now = DateTime(2026, 11, 18, 9);
      final one = remindersFor([autopay(nextOn: due)], now);
      final again = remindersFor([autopay(nextOn: due)], now);
      expect([for (final r in one) r.id], [for (final r in again) r.id]);
      expect(one.first.id, isNot(one.last.id));
    });
  });

  test('one line about each', () {
    final today = DateTime(2026, 11, 18);
    expect(
      autopayLine(autopay(nextOn: DateTime(2026, 11, 23)), today),
      '₹139 every month · next Mon, 23 Nov',
    );
    expect(
      autopayLine(autopay(), today),
      '₹139 every month · next day not known yet',
    );
    expect(
      autopayLine(autopay(endedAt: DateTime(2026, 11, 17)), today),
      '₹139 · cancelled',
    );
  });
}
