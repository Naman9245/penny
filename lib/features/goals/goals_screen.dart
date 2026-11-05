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
import 'package:penny/widgets/penny_mascot.dart';

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
    final list = goals.value ?? const <GoalProgress>[];

    return SafeArea(
      bottom: false,
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
          _Cheer(
            goals: list,
            savedThisMonth: savedBetween(deposits, month, nextMonth(month)),
            today: now,
          ),
          const SizedBox(height: 18),
          if (goals.hasValue && list.isEmpty)
            const _FirstGoal()
          else
            for (final goal in list) ...[
              _GoalCard(progress: goal, today: now),
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
      padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
      child: Row(
        children: [
          PennyMascot(mood: mood, size: 72),
          const SizedBox(width: 10),
          Expanded(child: Text(line, style: AppText.h3)),
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
    return BrutalCard(
      key: ValueKey('goal-${goal.id}'),
      color: progress.reached ? AppColors.sky : AppColors.white,
      onTap: () => context.push('/goals/${goal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(goal.title, style: AppText.h3)),
              if (progress.reached)
                const PennyMascot(
                  mood: PennyMood.celebrating,
                  size: 40,
                  bob: false,
                ),
            ],
          ),
          const SizedBox(height: 10),
          GoalProgressBar(progress: progress.progress),
          const SizedBox(height: 10),
          Text(
            '${formatPaise(progress.savedPaise)} of '
            '${formatPaise(goal.targetPaise)}',
            style: AppText.bodyStrong,
          ),
          Text(goalNeedLine(progress, today), style: AppText.small),
        ],
      ),
    );
  }
}
