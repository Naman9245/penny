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
import 'package:penny/widgets/first_show.dart';
import 'package:penny/widgets/icon_badge.dart';
import 'package:penny/widgets/meter_bar.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/pressable_area.dart';
import 'package:penny/widgets/speech_bubble.dart';

/// Penny's mood and what's safe to spend today, this month at a glance, and
/// the latest entries.
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
      child: FirstShowScope(
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
            Entrance(
              id: 'cards',
              child: CardPager(
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
            ),
            // Payments read from notifications, waiting to be checked.
            const Entrance(id: 'to-check', index: 1, child: ToCheckCard()),
            // Payments messages said are coming, like an autopay or an EMI.
            const Entrance(id: 'coming-up', index: 1, child: ComingUpCard()),
            // Last month's rent and bills, in a month's first week.
            const Entrance(
              id: 'fixed-bills',
              index: 1,
              child: FixedBillsCard(),
            ),
            const SizedBox(height: 16),
            Entrance(
              id: 'month',
              index: 2,
              child: _MonthCard(month: month, summary: summary),
            ),
            const SizedBox(height: 28),
            Entrance(
              id: 'recent',
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                                    'Nothing logged yet. Tap Add, type the '
                                    'amount, then tap a category.',
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
                                    onTap: () =>
                                        context.push('/txns/${txns[i].id}'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                    loading: () => const SizedBox(height: 72),
                    error: (error, stackTrace) => Text(
                      "Couldn't load entries: $error",
                      style: AppText.body,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      onTap: onTap,
      child: const Row(
        children: [
          IconBadge(
            icon: Icons.science_outlined,
            color: AppColors.white,
            size: 32,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demo data', style: AppText.label),
                Text(
                  'Made-up money to try Penny on. Yours is safe.',
                  style: AppText.small,
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

/// Penny, saying how today is going, over what's safe to spend. The whole
/// card opens the chat.
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
    final budgeted =
        status.budget.everydayPaise > 0 || status.oneGoNote != null;
    return BrutalCard(
      key: const ValueKey('penny-card'),
      color: mood.color,
      padding: const EdgeInsets.fromLTRB(10, 14, 14, 14),
      onTap: () => context.push('/chat'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PennyMascot(mood: mood, size: 84),
              const SizedBox(width: 2),
              Expanded(
                child: SpeechBubble(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MoodTag(mood: mood),
                      const SizedBox(height: 6),
                      Text(
                        celebrated == null
                            ? homeLine(
                                mood,
                                todaySpentPaise: status.todaySpentPaise,
                              )
                            : celebrationLine(celebrated),
                        style: AppText.h3,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (budgeted)
            _BudgetWell(status: status)
          else
            _NoBudgetWell(status: status),
          const SizedBox(height: 12),
          // The whole card opens the chat; this says so.
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 7, 14, 7),
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
                    size: 18,
                    color: AppColors.ink,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Talk to Penny',
                      style: AppText.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Penny's mood in a word, in its own colour.
class _MoodTag extends StatelessWidget {
  const _MoodTag({required this.mood});

  final PennyMood mood;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 2, 10, 3),
      decoration: BoxDecoration(
        color: mood.color,
        borderRadius: BorderRadius.circular(kPillRadius),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(mood.label, style: AppText.chip),
    );
  }
}

/// A well inside Penny's card: lighter than the card, with no outline of
/// its own, so it reads as part of her card rather than a card in a card.
class _Well extends StatelessWidget {
  const _Well({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('budget-box'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.wash,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

/// What's left of today's share, and where the month stands against the
/// budget. Today's line is the one the mood calendar colours today by.
class _BudgetWell extends StatelessWidget {
  const _BudgetWell({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final everyday = status.budget.everydayPaise;
    final share = status.sharePaise;
    final todaySpent = status.todaySpentPaise;
    final left = share - todaySpent;
    return _Well(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (everyday > 0) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                left >= 0
                    ? '${formatPaise(left)} left today'
                    : "${formatPaise(-left)} over today's share",
                key: const ValueKey('today-left'),
                style: AppText.h2,
              ),
            ),
            const SizedBox(height: 6),
            MeterBar(value: share == 0 ? 0 : todaySpent / share),
            const SizedBox(height: 4),
            Text(
              'Today ${formatPaise(todaySpent)} of your '
              '${formatPaise(share)} share',
              key: const ValueKey('today-line'),
              style: AppText.small,
            ),
            const SizedBox(height: 14),
            Text(
              '${formatPaise(status.everydaySpentPaise)} of '
              '${formatPaise(everyday)}',
              key: const ValueKey('budget-line'),
              style: AppText.bodyStrong,
            ),
            const SizedBox(height: 6),
            MeterBar(value: status.everydaySpentPaise / everyday),
            const SizedBox(height: 4),
            Text(
              'Everyday budget · ${daysLeftLabel(status.daysLeft)}',
              style: AppText.small,
            ),
          ] else
            const Text('Budget', style: AppText.small),
          for (final note in [?status.categoryNote, ?status.oneGoNote])
            _Note(icon: Icons.error_outline_rounded, text: note),
          if (status.forecast case final forecast?)
            _Note(
              key: const ValueKey('forecast-line'),
              icon: Icons.trending_up_rounded,
              text: forecast,
            ),
        ],
      ),
    );
  }
}

/// With no budget yet: where the month is heading, and a way to set one.
class _NoBudgetWell extends StatelessWidget {
  const _NoBudgetWell({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final forecast = status.forecast;
    return _Well(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (forecast != null) ...[
            Text(
              'This month · ${daysLeftLabel(status.daysLeft)}',
              style: AppText.small,
            ),
            const SizedBox(height: 2),
            Text(
              forecast,
              key: const ValueKey('forecast-line'),
              style: AppText.bodyStrong,
            ),
            const SizedBox(height: 10),
          ],
          const Text(
            "Give your everyday spending a budget, and I'll show what's safe "
            'to spend each day.',
            style: AppText.body,
          ),
          const SizedBox(height: 10),
          BrutalChip(
            key: const ValueKey('set-budget'),
            label: 'Set a budget',
            icon: Icons.savings_outlined,
            onTap: () => context.push('/budget'),
          ),
        ],
      ),
    );
  }
}

/// A line in the well about why Penny feels as she does, or where the
/// month is heading.
class _Note extends StatelessWidget {
  const _Note({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.ink),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
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
          Row(
            children: [
              IconBadge(
                icon: reached
                    ? Icons.emoji_events_outlined
                    : Icons.flag_rounded,
                color: AppColors.white,
                size: 32,
              ),
              const SizedBox(width: 10),
              Text(
                reached ? 'Goals reached' : 'Goals to reach',
                style: AppText.h3,
              ),
            ],
          ),
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
                        if (i > 0) const SizedBox(height: 14),
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

/// The month so far in one card: what went out, big, and what came in and
/// is left beside each other under it.
class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.month, required this.summary});

  final DateTime month;
  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KeyedSubtree(
            key: const ValueKey('stat-spent'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatLabel(
                    icon: Icons.north_east_rounded,
                    color: AppColors.pink,
                    label: 'Spent in ${DateFormat('MMMM').format(month)}',
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: AnimatedMoney(
                      summary.spentPaise,
                      id: 'spent',
                      style: AppText.hero,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const RowDivider(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Stat(
                    key: const ValueKey('stat-got'),
                    icon: Icons.south_west_rounded,
                    color: AppColors.mint,
                    label: 'Got',
                    value: MoneyText(summary.gotPaise, style: AppText.amount),
                  ),
                ),
                const ColoredBox(
                  color: AppColors.hairline,
                  child: SizedBox(width: 1.5),
                ),
                Expanded(
                  child: _Stat(
                    key: const ValueKey('stat-left'),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.yellow,
                    label: 'Left',
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
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, color: color, size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: AppText.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.hint,
  });

  final IconData icon;
  final Color color;
  final String label;
  final Widget value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final hint = this.hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatLabel(icon: icon, color: color, label: label),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: value,
          ),
          if (hint != null) ...[
            const SizedBox(height: 2),
            Text(hint, style: AppText.small),
          ],
        ],
      ),
    );
  }
}
