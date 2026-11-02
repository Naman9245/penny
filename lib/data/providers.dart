import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/chat_repository.dart';
import 'package:penny/data/db/app_database.dart';
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
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/insight_math.dart';

/// One database for the app's lifetime. Tests override it with an
/// in-memory one.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
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
  final now = DateTime.now();
  final month = monthStart(now);
  return budgetStatus(
    budget: ref.watch(budgetProvider).value ?? Budget.none,
    monthTxns: ref.watch(monthTxnsProvider(month)).value ?? const [],
    month: month,
    now: now,
  );
});

/// Penny's current mood, from where the month stands against the budget.
final pennyMoodProvider = Provider.autoDispose<PennyMood>(
  (ref) => ref.watch(budgetStatusProvider).mood,
);

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
      // Wait for My needs, so a request never goes out without the user's
      // rules or note and then looks changed a moment later.
      final rules = await ref.watch(yourRulesProvider.future);
      final note = await ref.watch(pennyNoteProvider.future);
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
