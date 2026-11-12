import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/goals/goal_widgets.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/first_show.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/progress_ring.dart';
import 'package:penny/widgets/speech_bubble.dart';

/// What the user is saving for, each goal with how far along it is, and
/// Penny cheering them on.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final goals = ref.watch(goalProgressProvider);
    final deposits = ref.watch(goalDepositsProvider).value ?? const [];
    final month = monthStart(now);
    final list = inListOrder(goals.value ?? const [], now);

    return SafeArea(
      bottom: false,
      child: FirstShowScope(
        child: ListView(
          // Room at the bottom so the Add button never hides the last goal.
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            Row(
              children: [
                const Expanded(child: Text('Goals', style: AppText.h1)),
                if (list.isNotEmpty)
                  BrutalChip(
                    key: const ValueKey('add-goal'),
                    label: 'New goal',
                    icon: Icons.add_rounded,
                    onTap: () => context.push('/goals/new'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Entrance(
              id: 'cheer',
              child: _Cheer(
                goals: list,
                savedThisMonth: savedBetween(deposits, month, nextMonth(month)),
                today: now,
              ),
            ),
            const SizedBox(height: 18),
            if (goals.hasValue && list.isEmpty)
              const Entrance(id: 'first', index: 1, child: _FirstGoal())
            else
              for (final (i, goal) in list.indexed) ...[
                Entrance(
                  id: goal.goal.id,
                  index: i + 1,
                  child: _GoalCard(progress: goal, today: now),
                ),
                const SizedBox(height: 14),
              ],
            if (list.isNotEmpty)
              const Text(
                'Money you put toward a goal is still yours, so it stays in '
                'Left on Home.',
                key: ValueKey('goals-left-note'),
                style: AppText.small,
              ),
          ],
        ),
      ),
    );
  }
}

/// Penny at the top, cheering on whatever is being saved.
class _Cheer extends StatelessWidget {
  const _Cheer({
    required this.goals,
    required this.savedThisMonth,
    required this.today,
  });

  final List<GoalProgress> goals;
  final int savedThisMonth;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final celebrated = justReachedGoal(goals, today);
    final (mood, line) = switch (savedThisMonth) {
      _ when celebrated != null => (
        PennyMood.celebrating,
        celebrationLine(celebrated),
      ),
      _ when goals.isEmpty => (
        PennyMood.happy,
        "Saving for something? Add a goal and I'll cheer you on.",
      ),
      > 0 => (
        PennyMood.happy,
        '${formatPaise(savedThisMonth)} put aside this month!',
      ),
      _ => (PennyMood.neutral, 'Every rupee counts. Put a little aside today!'),
    };
    return BrutalCard(
      key: const ValueKey('goals-cheer'),
      color: mood.color,
      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
      child: Row(
        children: [
          PennyMascot(mood: mood, size: 76),
          const SizedBox(width: 2),
          Expanded(
            child: SpeechBubble(child: Text(line, style: AppText.h3)),
          ),
        ],
      ),
    );
  }
}

class _FirstGoal extends StatelessWidget {
  const _FirstGoal();

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add your first goal', style: AppText.h2),
          const SizedBox(height: 4),
          const Text(
            'Like a Delhi trip in February, ₹15,000. Penny works out what to '
            'put aside each week.',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          BrutalButton(
            key: const ValueKey('add-first-goal'),
            label: 'Add a goal',
            icon: Icons.flag_rounded,
            expand: true,
            onPressed: () => context.push('/goals/new'),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.progress, required this.today});

  final GoalProgress progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final missed = progress.isMissed(today);
    return BrutalCard(
      key: ValueKey('goal-${goal.id}'),
      // A goal past its date has ended, so it goes the page's own cream.
      color: progress.reached
          ? AppColors.sky
          : missed
          ? AppColors.cream
          : AppColors.white,
      onTap: () => context.push('/goals/${goal.id}'),
      child: Row(
        children: [
          if (progress.reached)
            const PennyMascot(mood: PennyMood.celebrating, size: 60, bob: false)
          else
            ProgressRing(
              progress: progress.progress,
              size: 60,
              child: Text(
                '${(progress.progress * 100).floor()}%',
                style: AppText.chip,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(goal.title, style: AppText.h3)),
                    if (missed && !progress.reached) ...[
                      const SizedBox(width: 8),
                      const DatePassedPill(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatPaise(progress.savedPaise)} of '
                  '${formatPaise(goal.targetPaise)}',
                  style: AppText.bodyStrong,
                ),
                const SizedBox(height: 2),
                Text(goalNeedLine(progress, today), style: AppText.small),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
        ],
      ),
    );
  }
}
