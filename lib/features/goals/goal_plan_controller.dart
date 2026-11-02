import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/goal_plan.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';

/// What Penny would be sent to plan a goal, from the entries as they are
/// now. Null when there is nothing to plan with yet, or nothing to plan.
final goalPlanRequestProvider = StreamProvider.autoDispose
    .family<GoalPlanRequest?, String>((ref, goalId) async* {
      final rules = await ref.watch(yourRulesProvider.future);
      final note = await ref.watch(pennyNoteProvider.future);
      final budget = await ref.watch(budgetProvider.future);
      final goals = await ref.watch(goalsProvider.future);
      final deposits = await ref.watch(goalDepositsProvider.future);
      final progress = goalProgress(
        goals,
        deposits,
      ).where((goal) => goal.goal.id == goalId).firstOrNull;
      if (progress == null) {
        yield null;
        return;
      }
      final now = DateTime.now();
      final thisMonth = monthStart(now);
      final lastMonth = prevMonth(thisMonth);
      final insights = {
        lastMonth: await ref.watch(insightProvider(lastMonth).future),
        thisMonth: await ref.watch(insightProvider(thisMonth).future),
      };
      yield* ref
          .watch(txnRepositoryProvider)
          .watchBetween(insightHistoryStart(lastMonth), nextMonth(thisMonth))
          .map(
            (txns) => buildGoalPlanRequest(
              progress: progress,
              txns: txns,
              now: now,
              rules: rules,
              note: note,
              budget: budget,
              insights: insights,
            ),
          );
    });

/// Where asking Penny for a goal's plan stands.
@immutable
class PlanState {
  const PlanState({this.asking = false, this.failure, this.callsLeftToday});

  final bool asking;

  /// Why the last ask got no plan.
  final AiException? failure;

  /// From the server's last answer, when there was one.
  final int? callsLeftToday;
}

final goalPlanControllerProvider = NotifierProvider.autoDispose
    .family<GoalPlanController, PlanState, String>(GoalPlanController.new);

class GoalPlanController extends Notifier<PlanState> {
  GoalPlanController(this.goalId);

  final String goalId;

  @override
  PlanState build() => const PlanState();

  /// Sends [request] to Penny and keeps her answer as the goal's plan.
  Future<void> ask(GoalPlanRequest request) async {
    if (state.asking) return;
    // Read up front: the screen may close while Penny thinks, and the plan
    // is still worth keeping.
    final ai = ref.read(aiClientProvider);
    final plans = ref.read(goalPlanRepositoryProvider);
    state = PlanState(asking: true, callsLeftToday: state.callsLeftToday);
    try {
      final answer = await ai.planGoal(request);
      await plans.save(
        goalId: request.goalId,
        month: request.month.month,
        inputHash: request.inputHash,
        groupKeys: request.month.groupKeys,
        plan: answer.plan,
        model: answer.model,
      );
      if (ref.mounted) state = PlanState(callsLeftToday: answer.callsLeftToday);
    } on AiException catch (failure) {
      if (ref.mounted) {
        state = PlanState(
          failure: failure,
          callsLeftToday: state.callsLeftToday,
        );
      }
    }
  }
}
