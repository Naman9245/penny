import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/rules_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:uuid/uuid.dart';

// Made-up data to try every part of Penny on. It only ever goes into the
// demo database: none of it is anyone's real money, and every name in it is
// invented.

/// The demo's own database, beside the real one.
const demoDatabaseName = 'penny_demo';

/// The pref that marks a database as the demo's, so a reset can never empty
/// the user's own.
const _marker = 'demo_data';

Future<bool> _isDemo(AppDatabase db) async =>
    await (db.select(
      db.prefs,
    )..where((p) => p.name.equals(_marker))).getSingleOrNull() !=
    null;

/// Fills [db] with the demo, dated relative to [now], unless it has been
/// filled before. The same [now] always gives the same demo.
Future<void> fillDemoData(AppDatabase db, DateTime now) {
  return db.transaction(() async {
    if (!await _isDemo(db)) await _fill(db, now);
  });
}

/// Empties the demo in [db] and fills it again from fresh, all at once.
/// Throws, changing nothing, when [db] isn't the demo's.
Future<void> resetDemoData(AppDatabase db, DateTime now) {
  return db.transaction(() async {
    if (!await _isDemo(db)) {
      throw StateError('Only the demo database can be reset');
    }
    for (final table in db.allTables) {
      await db.delete(table).go();
    }
    await _fill(db, now);
  });
}

/// Made-up bank SMS dated [now], to paste into Add → Paste SMS: a shop
/// payment, a payment to a person, money received, and an OTP that Penny
/// should refuse. The formats are real; the numbers are not.
List<({String label, String text})> demoSms(DateTime now) {
  final slashes = DateFormat('dd/MM/yy').format(now);
  final dashes = DateFormat('dd-MM-yy').format(now);
  return [
    (
      label: 'A shop payment',
      text:
          'Sent Rs.250.00\nFrom HDFC Bank A/C *4821\nTo SWIGGY\nOn $slashes\n'
          'Ref 630512345678\nNot You?\n'
          'Call 18002586161/SMS BLOCK UPI to 7308080808',
    ),
    (
      label: 'A payment to a person',
      text:
          'Sent Rs.1200.00\nFrom HDFC Bank A/C *4821\nTo RAHUL KUMAR\n'
          'On $slashes\nRef 630598765432\nNot You?\n'
          'Call 18002586161/SMS BLOCK UPI to 7308080808',
    ),
    (
      label: 'Money received',
      text:
          'Credit Alert!\nRs.5000.00 credited to HDFC Bank A/c XX4821 on '
          '$dashes from VPA papa.sharma@okhdfcbank (UPI 630611112222)',
    ),
    (
      label: 'An OTP, which Penny refuses',
      text:
          'OTP is 482913 for txn of INR 649.00 at ZOMATO on HDFC Bank card '
          'ending 9034. Valid till 19:42. Do not share OTP for security '
          'reasons.',
    ),
  ];
}

Future<void> _fill(AppDatabase db, DateTime now) async {
  const uuid = Uuid();
  final random = math.Random(42);
  final today = dayStart(now);
  final thisMonth = monthStart(now);
  int between(int low, int high) => low + random.nextInt(high - low + 1);
  String pick(List<String> options) => options[random.nextInt(options.length)];

  final txns = <TxnsCompanion>[];
  void add(
    int rupees,
    DateTime at,
    String categoryId, {
    String? merchant,
    TxnType type = TxnType.debit,
    bool person = false,
  }) {
    // Nothing later than now, so this month runs up to today.
    if (at.isAfter(now)) return;
    txns.add(
      TxnsCompanion.insert(
        id: uuid.v7(),
        amountPaise: rupees * 100,
        type: type,
        categoryId: categoryId,
        merchant: Value(merchant),
        occurredAt: at,
        // Payments to people come from shared SMS, which say who they are.
        source: person ? TxnSource.share : TxnSource.manual,
        createdAt: at,
        updatedAt: at,
        payeeIsPerson: Value(person ? true : null),
      ),
    );
  }

  // Four months: three full ones and this one so far.
  for (var back = 3; back >= 0; back--) {
    final month = DateTime(thisMonth.year, thisMonth.month - back);
    final days = DateTime(month.year, month.month + 1, 0).day;
    DateTime on(int day, int hour, [int minute = 0]) =>
        DateTime(month.year, month.month, day, hour, minute);

    // Money in.
    add(15000, on(1, 9), 'pocket_money', type: TxnType.credit);
    if (back.isOdd) add(4000, on(15, 18), 'freelance', type: TxnType.credit);
    if (back == 2) add(349, on(20, 12), 'refund', type: TxnType.credit);

    // Paid in one go.
    add(8500, on(1, 10), 'rent', merchant: 'Sunrise PG');
    add(299, on(8, 20), 'bills', merchant: 'Airtel');
    add(199, on(5, 21), 'subscriptions', merchant: 'Netflix');
    add(119, on(12, 21), 'subscriptions', merchant: 'Spotify');
    if (back == 1) {
      add(450, on(18, 16), 'education', merchant: 'Sapna Book House');
    }

    // Everyday: canteen and metro on college days, delivery a few nights a
    // week and more at weekends, groceries on Saturdays, a cab now and then.
    for (var day = 1; day <= days; day++) {
      final weekday = DateTime(month.year, month.month, day).weekday;
      final weekend = weekday >= DateTime.saturday;
      if (!weekend) {
        add(between(60, 120), on(day, 13), 'food', merchant: 'College canteen');
        add(between(40, 60), on(day, 8, 30), 'travel', merchant: 'Namma Metro');
      }
      if (random.nextInt(7) < (weekend ? 4 : 2)) {
        add(
          between(180, 650),
          on(day, 21, 30),
          'food',
          merchant: pick(['Swiggy', 'Zomato']),
        );
      }
      if (weekday == DateTime.saturday) {
        add(
          between(400, 1100),
          on(day, 11),
          'groceries',
          merchant: pick(['DMart', 'BigBasket']),
        );
      }
      if (random.nextInt(10) == 0) {
        add(
          between(120, 350),
          on(day, 19),
          'travel',
          merchant: pick(['Uber', 'Rapido']),
        );
      }
    }

    // A few bigger days, and friends.
    add(
      between(600, 2500),
      on(between(3, 26), 17),
      'shopping',
      merchant: pick(['Myntra', 'Amazon']),
    );
    add(
      between(250, 600),
      on(between(5, 25), 19),
      'fun',
      merchant: 'BookMyShow',
    );
    add(
      between(150, 400),
      on(between(2, 27), 10),
      'health',
      merchant: 'Apollo Pharmacy',
    );
    add(
      between(300, 800),
      on(between(4, 24), 22),
      'other',
      merchant: 'Rahul Verma',
      person: true,
    );
    if (back.isEven) {
      add(
        500,
        on(between(10, 20), 20),
        'fun',
        merchant: 'Priya Nair',
        person: true,
      );
    }
  }
  await db.batch((batch) => batch.insertAll(db.txns, txns));

  // A budget per category: everyday ₹12,500, so a day's share is about ₹400.
  final budget = BudgetRepository(db, clock: () => now);
  for (final (categoryId, rupees) in const [
    ('food', 5000),
    ('groceries', 3000),
    ('travel', 1500),
    ('shopping', 1500),
    ('fun', 1000),
    ('health', 500),
    ('rent', 8500),
    ('bills', 300),
    ('subscriptions', 350),
  ]) {
    await budget.setAmount(categoryId, rupees * 100);
  }

  // My needs and a note.
  final rules = RulesRepository(db, clock: () => now);
  await rules.set(RuleKind.category, 'rent', TxnTag.necessary);
  await rules.set(RuleKind.category, 'groceries', TxnTag.necessary);
  await rules.set(RuleKind.shop, shopKey('Swiggy')!, TxnTag.wasteful);
  await PrefsRepository(db, clock: () => now).setNote(
    'Student in a PG in Bengaluru. Metro to college daily, saving for a '
    'Delhi trip.',
  );

  // Goals: one going, one reached yesterday, one whose date has passed.
  DateTime daysAgo(int days, int hour) =>
      today.subtract(Duration(days: days)).add(Duration(hours: hour));
  Future<void> goal(
    String title,
    int targetRupees,
    DateTime deadline,
    List<(int, DateTime)> money,
  ) async {
    final id = uuid.v7();
    final made = daysAgo(70, 12);
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: id,
            title: title,
            targetPaise: targetRupees * 100,
            deadline: dayStart(deadline),
            createdAt: made,
            updatedAt: made,
          ),
        );
    for (final (rupees, at) in money) {
      await db
          .into(db.goalDeposits)
          .insert(
            GoalDepositsCompanion.insert(
              id: uuid.v7(),
              goalId: id,
              amountPaise: rupees * 100,
              occurredAt: at,
              createdAt: at,
              updatedAt: at,
            ),
          );
    }
  }

  await goal('Delhi trip', 15000, today.add(const Duration(days: 100)), [
    (2000, daysAgo(60, 20)),
    (1500, daysAgo(30, 20)),
    (1000, daysAgo(3, 20)),
  ]);
  await goal('Headphones', 2500, today.add(const Duration(days: 20)), [
    (1500, daysAgo(25, 19)),
    (1000, daysAgo(1, 19)),
  ]);
  await goal('Concert ticket', 3000, today.subtract(const Duration(days: 5)), [
    (1200, daysAgo(20, 18)),
  ]);

  await db
      .into(db.prefs)
      .insert(PrefsCompanion.insert(name: _marker, value: '1', updatedAt: now));
}
