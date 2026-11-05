import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/chat_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/demo_data.dart';
import 'package:penny/data/goal_plan_repository.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/data/insight_repository.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/rules_repository.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/analysis_totals.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/insight_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Today, at midnight. It moves on by itself at midnight, and when the app
/// comes back after the phone slept through it, so Home and the calendar
/// never show yesterday as today. Time comes from `clock`, which tests can
/// fast-forward.
final todayProvider = NotifierProvider<Today, DateTime>(Today.new);

class Today extends Notifier<DateTime> {
  Timer? _midnight;

  @override
  DateTime build() {
    ref.onDispose(() => _midnight?.cancel());
    return _read();
  }

  /// Moves on if the day has changed meanwhile.
  void check() {
    final today = _read();
    if (today != state) state = today;
  }

  /// Today, with a timer set for just after the coming midnight.
  DateTime _read() {
    final now = clock.now();
    _midnight?.cancel();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), check);
    return dayStart(now);
  }
}

/// The phone's small key-value store, opened in main before the app
/// starts. Tests override it.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Opened in main'),
);

/// Whether the app shows the made-up demo instead of the user's own money.
/// Remembered across restarts.
final demoModeProvider = NotifierProvider<DemoMode, bool>(DemoMode.new);

class DemoMode extends Notifier<bool> {
  static const _key = 'demo_mode';

  Future<void>? _switching;

  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(_key) ?? false;

  /// Turns the demo on or off. The first time on, its database is filled
  /// before it shows, so it never flashes empty. Ignored while a switch is
  /// already under way.
  Future<void> set(bool on) =>
      _switching ??= _set(on).whenComplete(() => _switching = null);

  Future<void> _set(bool on) async {
    if (on == state) return;
    if (on) {
      final db = ref.read(databaseOpenerProvider)(demoDatabaseName);
      try {
        await fillDemoData(db, DateTime.now());
      } finally {
        await db.close();
      }
    }
    await ref.read(sharedPrefsProvider).setBool(_key, on);
    state = on;
  }
}

/// What Penny does with a payment she reads from a notification.
enum CaptureMode {
  /// It waits on Home for the user to add or skip it.
  check,

  /// It's saved as soon as it's read, unless it may already be logged or
  /// has no category to go in.
  save,
}

/// The user's choice of [CaptureMode], kept on this phone. Waiting to be
/// checked until they choose otherwise.
final captureModeProvider = NotifierProvider<CaptureModeSetting, CaptureMode>(
  CaptureModeSetting.new,
);

class CaptureModeSetting extends Notifier<CaptureMode> {
  static const _key = 'capture_mode';

  @override
  CaptureMode build() =>
      switch (ref.watch(sharedPrefsProvider).getString(_key)) {
        'save' => CaptureMode.save,
        _ => CaptureMode.check,
      };

  Future<void> set(CaptureMode mode) async {
    await ref.read(sharedPrefsProvider).setString(_key, mode.name);
    state = mode;
  }
}

/// Opens a database by name. Tests open temporary ones instead.
final databaseOpenerProvider = Provider<AppDatabase Function(String name)>(
  (ref) => AppDatabase.named,
);

/// The database on show: the user's own, or the demo's while demo mode is
/// on. Switching closes one and opens the other, and everything that reads
/// from it follows. Most tests override it with an in-memory one.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final name = ref.watch(demoModeProvider) ? demoDatabaseName : 'penny';
  final db = ref.watch(databaseOpenerProvider)(name);
  ref.onDispose(db.close);
  return db;
});

final txnRepositoryProvider = Provider<TxnRepository>(
  (ref) => TxnRepository(ref.watch(appDatabaseProvider)),
);

/// Entries in the month containing the given date, newest first.
final monthTxnsProvider = StreamProvider.autoDispose
    .family<List<Txn>, DateTime>(
      (ref, month) => ref.watch(txnRepositoryProvider).watchMonth(month),
    );

final monthSummaryProvider = StreamProvider.autoDispose
    .family<MonthSummary, DateTime>(
      (ref, month) => ref.watch(txnRepositoryProvider).watchMonthSummary(month),
    );

final recentTxnsProvider = StreamProvider.autoDispose<List<Txn>>(
  (ref) => ref.watch(txnRepositoryProvider).watchRecent(),
);

/// When the first entry happened: the mood calendar starts there.
final firstEntryProvider = StreamProvider.autoDispose<DateTime?>(
  (ref) => ref.watch(txnRepositoryProvider).watchFirstOccurredAt(),
);

final txnByIdProvider = FutureProvider.autoDispose.family<Txn?, String>(
  (ref, id) => ref.watch(txnRepositoryProvider).findById(id),
);

/// The live entry an SMS with this fingerprint was already imported as.
final txnByDedupeKeyProvider = FutureProvider.autoDispose.family<Txn?, String>(
  (ref, key) => ref.watch(txnRepositoryProvider).findByDedupeKey(key),
);

/// Where this month stands against the budget.
final budgetStatusProvider = Provider.autoDispose<BudgetStatus>((ref) {
  final today = ref.watch(todayProvider);
  final month = monthStart(today);
  return budgetStatus(
    budget: ref.watch(budgetProvider).value ?? Budget.none,
    monthTxns: ref.watch(monthTxnsProvider(month)).value ?? const [],
    month: month,
    now: today,
  );
});

/// The goal Penny is celebrating, if any: one reached today.
final celebratedGoalProvider = Provider.autoDispose<GoalProgress?>((ref) {
  final goals = ref.watch(goalProgressProvider).value ?? const [];
  return justReachedGoal(goals, ref.watch(todayProvider));
});

/// Penny's mood now: today's on the mood calendar, by the same rule, so
/// Home and the calendar always agree. Neutral without an everyday budget.
final pennyMoodProvider = Provider.autoDispose<PennyMood>((ref) {
  final today = ref.watch(todayProvider);
  final month = monthStart(today);
  final moods = dayMoods(
    budget: ref.watch(budgetProvider).value ?? Budget.none,
    monthTxns: ref.watch(monthTxnsProvider(month)).value ?? const [],
    month: month,
    now: today,
    goalDays: ref.watch(goalDaysProvider),
  );
  return moods[today.day] ?? PennyMood.neutral;
});

/// Per-category totals for the month containing the given date.
final categoryTotalsProvider = StreamProvider.autoDispose
    .family<List<CategoryTotal>, DateTime>(
      (ref, month) =>
          ref.watch(txnRepositoryProvider).watchCategoryTotals(month),
    );

/// The six months ending with the one containing the given date.
final monthlyTotalsProvider = StreamProvider.autoDispose
    .family<List<MonthTotals>, DateTime>(
      (ref, month) =>
          ref.watch(txnRepositoryProvider).watchMonthlyTotals(month),
    );

final insightRepositoryProvider = Provider<InsightRepository>(
  (ref) => InsightRepository(ref.watch(appDatabaseProvider)),
);

/// Penny's saved report for the month containing the given date, if any.
final insightProvider = StreamProvider.autoDispose
    .family<SavedInsight?, DateTime>(
      (ref, month) => ref.watch(insightRepositoryProvider).watch(month),
    );

/// What Penny would be sent for that month, from the entries as they are
/// now.
final insightRequestProvider = StreamProvider.autoDispose
    .family<InsightRequest, DateTime>((ref, month) async* {
      final start = monthStart(month);
      // Wait for My needs and the budget, so a request never goes out
      // without them and then looks changed a moment later.
      final rules = await ref.watch(yourRulesProvider.future);
      final note = await ref.watch(pennyNoteProvider.future);
      final budget = await ref.watch(budgetProvider.future);
      yield* ref
          .watch(txnRepositoryProvider)
          .watchBetween(insightHistoryStart(start), nextMonth(start))
          .map(
            (txns) => buildInsightRequest(
              month: start,
              txns: txns,
              now: DateTime.now(),
              rules: rules,
              note: note,
              budget: budget,
            ),
          );
    });

final rulesRepositoryProvider = Provider<RulesRepository>(
  (ref) => RulesRepository(ref.watch(appDatabaseProvider)),
);

/// What My needs says.
final yourRulesProvider = StreamProvider.autoDispose<YourRules>(
  (ref) => ref.watch(rulesRepositoryProvider).watch(),
);

final prefsRepositoryProvider = Provider<PrefsRepository>(
  (ref) => PrefsRepository(ref.watch(appDatabaseProvider)),
);

/// What the user told Penny about their life, if anything.
final pennyNoteProvider = StreamProvider.autoDispose<String?>(
  (ref) => ref.watch(prefsRepositoryProvider).watchNote(),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(appDatabaseProvider)),
);

/// The chat with Penny, oldest message first.
final chatMessagesProvider = StreamProvider.autoDispose<List<ChatMessage>>(
  (ref) => ref.watch(chatRepositoryProvider).watch(),
);

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

/// What the user means to spend each month.
final budgetProvider = StreamProvider.autoDispose<Budget>(
  (ref) => ref.watch(budgetRepositoryProvider).watch(),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => GoalRepository(ref.watch(appDatabaseProvider)),
);

/// Live goals, soonest deadline first.
final goalsProvider = StreamProvider.autoDispose<List<Goal>>(
  (ref) => ref.watch(goalRepositoryProvider).watchGoals(),
);

/// The money put toward every live goal, oldest first.
final goalDepositsProvider = StreamProvider.autoDispose<List<GoalDeposit>>(
  (ref) => ref.watch(goalRepositoryProvider).watchDeposits(),
);

/// Every live goal with what has been put toward it, soonest deadline
/// first.
final goalProgressProvider =
    Provider.autoDispose<AsyncValue<List<GoalProgress>>>((ref) {
      final deposits = ref.watch(goalDepositsProvider).value ?? const [];
      return ref
          .watch(goalsProvider)
          .whenData((goals) => goalProgress(goals, deposits));
    });

/// The days goals were reached: sky blue on the mood calendar.
final goalDaysProvider = Provider.autoDispose<Set<DateTime>>(
  (ref) => {
    for (final goal in ref.watch(goalProgressProvider).value ?? const [])
      ?goal.reachedOn,
  },
);

final goalPlanRepositoryProvider = Provider<GoalPlanRepository>(
  (ref) => GoalPlanRepository(ref.watch(appDatabaseProvider)),
);

/// Penny's saved plan for a goal, if any.
final goalPlanProvider = StreamProvider.autoDispose
    .family<SavedGoalPlan?, String>(
      (ref, goalId) => ref.watch(goalPlanRepositoryProvider).watch(goalId),
    );

/// That month's spending split into necessary, wasteful and not sorted.
final tagSplitProvider = Provider.autoDispose
    .family<AsyncValue<TagSplit>, DateTime>((ref, month) {
      final saved = ref.watch(insightProvider(month)).value;
      final rules = ref.watch(yourRulesProvider).value ?? YourRules.none;
      return ref
          .watch(monthTxnsProvider(month))
          .whenData((txns) => splitByTag(txns, saved, rules: rules));
    });
