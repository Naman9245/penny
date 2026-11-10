import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/goals/goal_widgets.dart';
import 'package:penny/features/home/coming_up_card.dart';
import 'package:penny/features/home/fixed_bills_card.dart';
import 'package:penny/features/home/to_check_card.dart';
import 'package:penny/features/settings/settings_sheet.dart';
import 'package:penny/features/transactions/txn_tile.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/penny_pose.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/card_pager.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/pressable_area.dart';

/// Penny's mood, this month at a glance, and the latest entries.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final month = monthStart(today);
    final mood = ref.watch(pennyMoodProvider);
    final status = ref.watch(budgetStatusProvider);
    final summary = ref
        .watch(monthSummaryProvider(month))
        .when(
          data: (summary) => summary,
          loading: () => MonthSummary.empty,
          error: (error, stackTrace) => MonthSummary.empty,
        );
    final recent = ref.watch(recentTxnsProvider);
    final demo = ref.watch(demoModeProvider);
    final goals = inListOrder(
      ref.watch(goalProgressProvider).value ?? const [],
      today,
    );
    final reached = [
      for (final goal in goals)
        if (goal.reached) goal,
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(DateTime.now()), style: AppText.h1),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEEE, d MMMM').format(today),
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
              BrutalIconButton(
                icon: Icons.settings_outlined,
                semanticLabel: 'Settings',
                size: 44,
                onPressed: () => showSettingsSheet(context),
              ),
            ],
          ),
          // Made-up money must never pass for the user's own.
          if (demo) ...[
            const SizedBox(height: 14),
            _DemoBanner(onTap: () => showSettingsSheet(context)),
          ],
          const SizedBox(height: 18),
          // Slide Penny aside for the goals still to reach, then the ones
          // reached.
          CardPager(
            key: const ValueKey('home-cards'),
            labels: const ['Penny', 'Goals to reach', 'Goals reached'],
            pages: [
              _PennyCard(
                mood: mood,
                status: status,
                celebrated: ref.watch(celebratedGoalProvider),
              ),
              _GoalsCard(
                goals: [
                  for (final goal in goals)
                    if (!goal.reached) goal,
                ],
                today: today,
              ),
              _GoalsCard(goals: reached, today: today, reached: true),
            ],
          ),
          if (status.budget.isEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: BrutalChip(
                key: const ValueKey('set-budget'),
                label: 'Set a budget',
                icon: Icons.savings_outlined,
                onTap: () => context.push('/budget'),
              ),
            ),
          ],
          // Payments read from notifications, waiting to be checked.
          const ToCheckCard(),
          // Payments messages said are coming, like an autopay or an EMI.
          const ComingUpCard(),
          // Last month's rent and bills, in a month's first week.
          const FixedBillsCard(),
          const SizedBox(height: 16),
          _MonthBento(month: month, summary: summary),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(child: Text('Recent', style: AppText.h2)),
              BrutalChip(
                label: 'See all',
                icon: Icons.receipt_long_rounded,
                onTap: () => context.push('/txns'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          recent.when(
            data: (txns) => txns.isEmpty
                ? const BrutalCard(
                    child: Row(
                      children: [
                        PennyMascot(pose: PennyPose.sleepy, size: 56),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Nothing logged yet. Tap Add, type the amount, '
                            'then tap a category.',
                            style: AppText.body,
                          ),
                        ),
                      ],
                    ),
                  )
                : BrutalCard(
                    padding: EdgeInsets.zero,
                    clipChild: true,
                    child: Column(
                      children: [
                        for (var i = 0; i < txns.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          TxnTile(
                            txn: txns[i],
                            showDay: true,
                            onTap: () => context.push('/txns/${txns[i].id}'),
                          ),
                        ],
                      ],
                    ),
                  ),
            loading: () => const SizedBox(height: 72),
            error: (error, stackTrace) =>
                Text("Couldn't load entries: $error", style: AppText.body),
          ),
        ],
      ),
    );
  }

  static String _greeting(DateTime now) => switch (now.hour) {
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      key: const ValueKey('demo-banner'),
      color: AppColors.sky,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      onTap: onTap,
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: AppColors.ink),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demo data', style: AppText.label),
                Text(
                  'Made-up money to try Penny on. Yours is safe.',
                  style: AppText.body,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.ink),
        ],
      ),
    );
  }
}

class _PennyCard extends StatelessWidget {
  const _PennyCard({
    required this.mood,
    required this.status,
    required this.celebrated,
  });

  final PennyMood mood;
  final BudgetStatus status;

  /// The goal Penny is celebrating, if she is.
  final GoalProgress? celebrated;

  @override
  Widget build(BuildContext context) {
    final celebrated = this.celebrated;
    final budget =
        status.budget.everydayPaise > 0 ||
        status.oneGoNote != null ||
        status.forecast != null;
    return BrutalCard(
      key: const ValueKey('penny-card'),
      color: mood.color,
      padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
      onTap: () => context.push('/chat'),
      child: Row(
        children: [
          PennyMascot(mood: mood),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(kPillRadius),
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: Text(mood.label, style: AppText.chip),
                ),
                const SizedBox(height: 8),
                Text(
                  celebrated == null
                      ? homeLine(mood, todaySpentPaise: status.todaySpentPaise)
                      : celebrationLine(celebrated),
                  style: AppText.h3,
                ),
                if (budget) ...[
                  const SizedBox(height: 10),
                  _BudgetBox(status: status),
                ],
                const SizedBox(height: 10),
                // The whole card opens the chat; this says so.
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
                  decoration: brutalDecoration(
                    color: AppColors.yellow,
                    radius: kPillRadius,
                    borderWidth: 2,
                    shadow: const Offset(2, 2),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 16,
                        color: AppColors.ink,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Talk to Penny',
                          style: AppText.chip,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Where the month and today stand against the budget, boxed off from
/// Penny's line so it can't be read as a goal. Today's line is the one the
/// mood calendar colours today by.
class _BudgetBox extends StatelessWidget {
  const _BudgetBox({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final everyday = status.budget.everydayPaise;
    final forecast = status.forecast;
    final days = daysLeftLabel(status.daysLeft);
    return Container(
      key: const ValueKey('budget-box'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            everyday > 0
                ? 'Everyday budget · $days'
                : status.budget.isEmpty
                ? 'This month · $days'
                : 'Budget',
            style: AppText.small,
          ),
          if (everyday > 0) ...[
            Text(
              '${formatPaise(status.everydaySpentPaise)} of '
              '${formatPaise(everyday)}',
              key: const ValueKey('budget-line'),
              style: AppText.bodyStrong,
            ),
            Text(
              'Today ${formatPaise(status.todaySpentPaise)} of your '
              '${formatPaise(status.sharePaise)} share',
              key: const ValueKey('today-line'),
              style: AppText.body,
            ),
          ],
          for (final note in [?status.categoryNote, ?status.oneGoNote])
            Text(note, style: AppText.body),
          if (forecast != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                forecast,
                key: const ValueKey('forecast-line'),
                style: AppText.small.copyWith(color: AppColors.ink),
              ),
            ),
        ],
      ),
    );
  }
}

/// The goals still to reach, or the ones reached, on the card beside
/// Penny's.
class _GoalsCard extends StatelessWidget {
  const _GoalsCard({
    required this.goals,
    required this.today,
    this.reached = false,
  });

  final List<GoalProgress> goals;
  final DateTime today;
  final bool reached;

  /// Goals shown on the card; the rest are on Goals.
  static const _shown = 2;

  @override
  Widget build(BuildContext context) {
    final more = goals.length - _shown;
    return BrutalCard(
      key: ValueKey(reached ? 'goals-reached' : 'goals-to-reach'),
      color: reached ? AppColors.sky : AppColors.lavender,
      // The pager gives every card the tallest one's height: the title keeps
      // to the top, the button to the foot, and the goals sit between.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(reached ? 'Goals reached' : 'Goals to reach', style: AppText.h3),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: goals.isEmpty
                ? Row(
                    children: [
                      const PennyMascot(
                        mood: PennyMood.happy,
                        size: 64,
                        bob: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          reached
                              ? 'None yet. Every goal you reach lands here, '
                                    'and Penny celebrates it.'
                              : 'No goals yet. Add one and Penny works out '
                                    'what to put aside each week.',
                          style: AppText.body,
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, goal) in goals.take(_shown).indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        _GoalRow(progress: goal, today: today),
                      ],
                      if (more > 0) ...[
                        const SizedBox(height: 10),
                        Text(
                          more == 1
                              ? 'And 1 more on Goals'
                              : 'And $more more on Goals',
                          style: AppText.small.copyWith(color: AppColors.ink),
                        ),
                      ],
                    ],
                  ),
          ),
          if (goals.isEmpty && !reached)
            BrutalButton(
              key: const ValueKey('home-add-goal'),
              label: 'Add a goal',
              icon: Icons.add_rounded,
              color: AppColors.white,
              expand: true,
              onPressed: () => context.push('/goals/new'),
            )
          else
            BrutalButton(
              label: 'All goals',
              icon: Icons.flag_rounded,
              color: AppColors.white,
              expand: true,
              onPressed: () => context.go('/goals'),
            ),
        ],
      ),
    );
  }
}

/// One goal on the goals card: how far along it is, or when it was
/// reached. Tap it for its page.
class _GoalRow extends StatelessWidget {
  const _GoalRow({required this.progress, required this.today});

  final GoalProgress progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: PressableArea(
          key: ValueKey('home-goal-${goal.id}'),
          radius: 8,
          onTap: () => context.push('/goals/${goal.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.title,
                      style: AppText.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    progress.reached
                        ? formatPaise(goal.targetPaise)
                        : '${formatPaise(progress.savedPaise)} of '
                              '${formatPaise(goal.targetPaise)}',
                    style: AppText.label,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // What it needs each week is on its page; here, how far along.
              if (progress.reached)
                Text(
                  goalNeedLine(progress, today),
                  style: AppText.small.copyWith(color: AppColors.ink),
                )
              else if (progress.isMissed(today))
                Row(
                  children: [
                    Expanded(
                      child: GoalProgressBar(progress: progress.progress),
                    ),
                    const SizedBox(width: 8),
                    const DatePassedPill(),
                  ],
                )
              else
                GoalProgressBar(progress: progress.progress),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthBento extends StatelessWidget {
  const _MonthBento({required this.month, required this.summary});

  final DateTime month;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatCard(
          key: const ValueKey('stat-spent'),
          label: 'Spent in ${DateFormat('MMMM').format(month)}',
          color: AppColors.pink,
          value: MoneyText(summary.spentPaise, style: AppText.hero),
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  key: const ValueKey('stat-got'),
                  label: 'Got',
                  color: AppColors.mint,
                  value: MoneyText(summary.gotPaise, style: AppText.amount),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCard(
                  key: const ValueKey('stat-left'),
                  label: 'Left',
                  color: AppColors.yellow,
                  value: summary.hasIncome
                      ? MoneyText(summary.leftPaise, style: AppText.amount)
                      : const Text('—', style: AppText.amount),
                  hint: !summary.hasIncome
                      ? 'Log income to see this'
                      : summary.investedPaise > 0
                      ? '${formatPaise(summary.investedPaise)} invested'
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.label,
    required this.color,
    required this.value,
    this.hint,
  });

  final String label;
  final Color color;
  final Widget value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return BrutalCard(
      color: color,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: value,
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: AppText.small.copyWith(color: AppColors.ink)),
          ],
        ],
      ),
    );
  }
}
