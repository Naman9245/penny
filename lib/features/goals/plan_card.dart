import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/goals/goal_plan_controller.dart';
import 'package:penny/features/report/sent_sheet.dart';
import 'package:penny/models/goal_plan.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/penny_pose.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/goal_plan.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_pill.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/waiting_bar.dart';

/// Penny's plan for a goal that is still going: ask for one, then the cuts
/// with what each saves a month, against what the goal needs. Penny picks
/// the cuts; every amount is worked out on the phone.
class PlanCard extends ConsumerWidget {
  const PlanCard({super.key, required this.progress, required this.today});

  final GoalProgress progress;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalId = progress.goal.id;
    final saved = ref.watch(goalPlanProvider(goalId)).value;
    final request = ref.watch(goalPlanRequestProvider(goalId));
    final state = ref.watch(goalPlanControllerProvider(goalId));
    final setUp = ref.watch(aiClientProvider).isSetUp;
    final ask = request.value;
    final onAsk = setUp && ask != null && !state.asking
        ? () => ref.read(goalPlanControllerProvider(goalId).notifier).ask(ask)
        : null;
    final blocker = !setUp
        ? "Penny's AI isn't set up in this build yet."
        : ask == null && !request.isLoading
        ? 'Log two weeks of spending first, so Penny has something to go by.'
        : null;

    if (saved == null) {
      return _Ask(
        perWeekPaise: progress.perWeekPaise(today),
        month: ask?.month.month,
        state: state,
        blocker: blocker,
        onAsk: onAsk,
      );
    }
    final monthTxns =
        ref.watch(monthTxnsProvider(saved.month)).value ?? const [];
    return _Plan(
      saved: saved,
      views: planCutViews(saved, monthTxns, today),
      needPaise: progress.perMonthPaise(today),
      partMonth: monthStart(today) == saved.month,
      goalChanged: saved.inputHash != goalFingerprint(progress.goal),
      newerMonth: ask != null && ask.month.month != saved.month
          ? ask.month.month
          : null,
      request: ask,
      state: state,
      onAgain: onAsk,
    );
  }
}

/// Words for a plan Penny couldn't make. Plans have a daily limit of their
/// own.
String _problem(AiException failure) => switch (failure) {
  AiException(failure: AiFailure.dailyLimit, :final limit) =>
    'Penny can plan ${limit ?? 'only a few'} times a day. Try again '
        'tomorrow.',
  _ => failure.message,
};

class _Ask extends StatelessWidget {
  const _Ask({
    required this.perWeekPaise,
    required this.month,
    required this.state,
    required this.blocker,
    required this.onAsk,
  });

  final int perWeekPaise;

  /// The month Penny would go by, once there is one.
  final DateTime? month;
  final PlanState state;
  final String? blocker;
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final month = this.month;
    final failure = state.asking ? null : state.failure;
    final blocker = this.blocker;
    return BrutalCard(
      key: const ValueKey('plan-ask'),
      color: AppColors.lavender,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Glasses on while she works the plan out.
              PennyMascot(
                pose: state.asking ? PennyPose.analyzing : null,
                size: 56,
                bob: state.asking,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Where can ${formatPaise(perWeekPaise)} a week come from? '
                  'Penny picks what to cut.',
                  style: AppText.h3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            month == null
                ? 'She goes by a month of your spending as totals per shop, '
                      'and this goal. Never your SMS or the names of people '
                      'you pay.'
                : 'She goes by your ${DateFormat('MMMM').format(month)} '
                      'spending as totals per shop, and this goal. Never '
                      'your SMS or the names of people you pay.',
            style: AppText.small.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 14),
          if (state.asking)
            const WaitingBar()
          else ...[
            if (failure != null) ...[
              Text(_problem(failure), style: AppText.bodyStrong),
              const SizedBox(height: 10),
            ],
            if (blocker != null) ...[
              Text(blocker, style: AppText.bodyStrong),
              const SizedBox(height: 10),
            ],
            BrutalButton(
              key: const ValueKey('plan-goal'),
              label: failure == null ? 'Plan with Penny' : 'Try again',
              icon: Icons.auto_awesome_rounded,
              expand: true,
              onPressed: onAsk,
            ),
          ],
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({
    required this.saved,
    required this.views,
    required this.needPaise,
    required this.partMonth,
    required this.goalChanged,
    required this.newerMonth,
    required this.request,
    required this.state,
    required this.onAgain,
  });

  final SavedGoalPlan saved;
  final List<PlanCutView> views;

  /// What the goal still needs a month.
  final int needPaise;

  /// The plan goes by a month that is still going.
  final bool partMonth;
  final bool goalChanged;

  /// A later month Penny could plan with now.
  final DateTime? newerMonth;
  final GoalPlanRequest? request;
  final PlanState state;
  final VoidCallback? onAgain;

  @override
  Widget build(BuildContext context) {
    final total = planSavingPaise(views);
    final enough = total >= needPaise;
    final summary = saved.plan.summary;
    final failure = state.asking ? null : state.failure;
    final newerMonth = this.newerMonth;
    final request = this.request;
    final month = DateFormat('MMMM').format(saved.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.isNotEmpty) ...[
          BrutalCard(
            color: AppColors.lavender,
            child: Row(
              children: [
                PennyMascot(
                  mood: PennyMood.happy,
                  pose: state.asking ? PennyPose.analyzing : null,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(summary, style: AppText.h3)),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (views.isEmpty)
          const Text(
            'Penny found nothing sensible to cut. A later date or a little '
            'extra income would help.',
            style: AppText.body,
          ),
        for (final view in views) ...[
          _CutCard(view: view),
          const SizedBox(height: 12),
        ],
        BrutalCard(
          key: const ValueKey('plan-total'),
          color: enough ? AppColors.mint : AppColors.yellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                enough
                    ? 'These free about ${formatPaise(total)} a month, '
                          'enough!'
                    : 'About ${formatPaise(total)} of the '
                          '${formatPaise(needPaise)} a month you need.',
                style: AppText.h3,
              ),
              const SizedBox(height: 4),
              Text(
                partMonth
                    ? 'Going by $month so far, counted as a whole month.'
                    : 'Going by your $month spending.',
                style: AppText.small.copyWith(color: AppColors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (goalChanged)
          const Text(
            'Your goal changed since Penny planned.',
            style: AppText.bodyStrong,
          )
        else if (newerMonth != null)
          Text(
            "Penny can plan with ${DateFormat('MMMM').format(newerMonth)}'s "
            'spending now.',
            style: AppText.bodyStrong,
          ),
        if (failure != null) Text(_problem(failure), style: AppText.bodyStrong),
        if (state.asking) ...[const SizedBox(height: 8), const WaitingBar()],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            BrutalChip(
              key: const ValueKey('plan-again'),
              label: 'Plan again',
              icon: Icons.refresh_rounded,
              onTap: onAgain,
            ),
            BrutalChip(
              key: const ValueKey('plan-chat'),
              label: 'Ask Penny about this',
              icon: Icons.chat_bubble_outline_rounded,
              onTap: () => context.push('/chat'),
            ),
            if (request != null)
              BrutalChip(
                key: const ValueKey('plan-see-sent'),
                label: 'See what Penny sends',
                icon: Icons.visibility_outlined,
                onTap: () =>
                    showSentSheet(context, request.month, goal: request.goal),
              ),
          ],
        ),
      ],
    );
  }
}

class _CutCard extends StatelessWidget {
  const _CutCard({required this.view});

  final PlanCutView view;

  @override
  Widget build(BuildContext context) {
    final cut = view.cut.cut;
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(view.title, style: AppText.h3),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                label: cut.label,
                excludeSemantics: true,
                child: BrutalPill(label: cut.short, color: AppColors.white),
              ),
              BrutalPill(
                label: 'About ${formatPaise(view.savePaise)} a month',
                color: AppColors.mint,
              ),
            ],
          ),
          if (view.cut.tip.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(view.cut.tip, style: AppText.body),
          ],
        ],
      ),
    );
  }
}
