import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/demo_data.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/rules_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/sms_parser.dart';

void main() {
  // An evening early in a month, as when the demo is first tried.
  final now = DateTime(2026, 11, 2, 18);
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Every entry as one line, in a fixed order, to compare two demos.
  Future<List<String>> lines(AppDatabase db) async {
    final txns = await db.select(db.txns).get();
    return [
      for (final t in txns)
        '${t.occurredAt.toIso8601String()} ${t.type.name} ${t.amountPaise} '
            '${t.categoryId} ${t.merchant} ${t.payeeIsPerson}',
    ]..sort();
  }

  Future<List<GoalProgress>> goals(AppDatabase db) async {
    final repo = GoalRepository(db);
    return goalProgress(
      await repo.watchGoals().first,
      await repo.watchDeposits().first,
    );
  }

  group('fillDemoData', () {
    test('fills four months up to now, with income and people', () async {
      await fillDemoData(db, now);
      final txns = await db.select(db.txns).get();

      final months = {for (final t in txns) monthStart(t.occurredAt)};
      expect(months, {
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 11),
      });
      expect(txns.where((t) => t.occurredAt.isAfter(now)), isEmpty);

      final pocketMoney = txns.where((t) => t.categoryId == 'pocket_money');
      expect(pocketMoney, hasLength(4));
      expect(
        pocketMoney.every(
          (t) => t.type == TxnType.credit && t.amountPaise == 1500000,
        ),
        isTrue,
      );
      expect(txns.where((t) => t.categoryId == 'freelance'), hasLength(2));
      expect(txns.where((t) => t.categoryId == 'refund'), hasLength(1));

      final people = txns.where((t) => t.payeeIsPerson ?? false);
      expect(
        {for (final t in people) t.merchant},
        {'Rahul Verma', 'Priya Nair'},
      );
      expect({
        for (final t in txns) t.merchant,
      }, containsAll(['Swiggy', 'Namma Metro', 'Sunrise PG', 'Netflix']));
    });

    test('gives each category a budget that adds up', () async {
      await fillDemoData(db, now);
      final budget = await BudgetRepository(db).watch().first;

      expect(budget.byCategory, hasLength(9));
      expect(budget.everydayPaise, 1790000);
      expect(budget.oneGoPaise, 915000);
      expect(budget.totalPaise, 2705000);
    });

    test('has a goal going, one reached today and one missed', () async {
      await fillDemoData(db, now);
      final progress = {for (final p in await goals(db)) p.goal.title: p};

      expect(
        progress.keys,
        unorderedEquals(['Delhi trip', 'Headphones', 'Concert ticket']),
      );
      expect(progress['Delhi trip']!.savedPaise, 450000);
      expect(progress['Delhi trip']!.daysLeft(now), 100);
      expect(progress['Headphones']!.reachedOn, DateTime(2026, 11, 2));
      expect(justReached(progress.values, now), isTrue);
      expect(progress['Concert ticket']!.isMissed(now), isTrue);
    });

    test("fills My needs and a note, and leaves Penny's answers", () async {
      await fillDemoData(db, now);

      final rules = await RulesRepository(db).watch().first;
      expect(rules.categories, {
        'rent': TxnTag.necessary,
        'groceries': TxnTag.necessary,
      });
      expect(rules.shops, {'swiggy': TxnTag.wasteful});
      expect(await PrefsRepository(db).watchNote().first, contains('Delhi'));
      expect(await db.select(db.insights).get(), isEmpty);
      expect(await db.select(db.chatMessages).get(), isEmpty);
      expect(await db.select(db.goalPlans).get(), isEmpty);
    });

    test('gives last month every mood, and today a goal', () async {
      await fillDemoData(db, now);
      final budget = await BudgetRepository(db).watch().first;
      final txns = await db.select(db.txns).get();
      final first = txns
          .map((t) => t.occurredAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      Map<int, PennyMood> moodsOf(DateTime month, Set<DateTime> goalDays) =>
          dayMoods(
            budget: budget,
            monthTxns: txns.where((t) => monthStart(t.occurredAt) == month),
            month: month,
            now: now,
            firstEntry: first,
            goalDays: goalDays,
          );

      final october = moodsOf(DateTime(2026, 10), const {});
      expect(
        october.values.toSet(),
        containsAll([PennyMood.happy, PennyMood.worried, PennyMood.sad]),
      );
      expect(moodSummary(october)!.mostly, PennyMood.happy);

      final goalDays = {for (final p in await goals(db)) ?p.reachedOn};
      expect(moodsOf(DateTime(2026, 11), goalDays)[2], PennyMood.celebrating);
    });

    test('is the same every time for the same day', () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);

      await fillDemoData(db, now);
      await fillDemoData(other, now);
      expect(await lines(other), await lines(db));
    });

    test('fills a database only once', () async {
      await fillDemoData(db, now);
      final before = await lines(db);

      await fillDemoData(db, now.add(const Duration(days: 3)));
      expect(await lines(db), before);
    });
  });

  group('resetDemoData', () {
    test('starts the demo again from fresh', () async {
      await fillDemoData(db, now);
      final fresh = await lines(db);
      await TxnRepository(db).add(
        amountPaise: 99900,
        type: TxnType.debit,
        categoryId: 'fun',
        occurredAt: now,
        merchant: 'Arcade',
      );

      await resetDemoData(db, now);
      expect(await lines(db), fresh);
    });

    test("refuses a database that isn't the demo's", () async {
      await TxnRepository(db).add(
        amountPaise: 2000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: now,
        merchant: 'Chai point',
      );

      await expectLater(resetDemoData(db, now), throwsStateError);
      final txns = await db.select(db.txns).get();
      expect(txns.single.merchant, 'Chai point');
    });
  });

  test('each sample SMS reads as its label says', () {
    final samples = demoSms(now);
    expect(samples, hasLength(4));

    final shop = parseSms(samples[0].text, now: now) as SmsTxn;
    expect(shop.type, TxnType.debit);
    expect(shop.amountPaise, 25000);
    expect(shop.payee, 'Swiggy');
    expect(shop.payeeIsPerson, isFalse);
    expect(dayStart(shop.occurredAt!), dayStart(now));

    final person = parseSms(samples[1].text, now: now) as SmsTxn;
    expect(person.type, TxnType.debit);
    expect(person.amountPaise, 120000);
    expect(person.payeeIsPerson, isTrue);

    final got = parseSms(samples[2].text, now: now) as SmsTxn;
    expect(got.type, TxnType.credit);
    expect(got.amountPaise, 500000);
    expect(dayStart(got.occurredAt!), dayStart(now));

    expect(
      parseSms(samples[3].text, now: now),
      isA<SmsIgnored>().having((s) => s.reason, 'reason', IgnoreReason.otp),
    );
  });
}
