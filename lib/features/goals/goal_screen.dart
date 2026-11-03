import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/goals/goal_widgets.dart';
import 'package:penny/features/goals/plan_card.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/widgets/amount_sheet.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// One goal: how far along it is, money in and out, and what's been put in.
class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key, required this.goalId});

  final String goalId;

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends ConsumerState<GoalScreen> {
  // Rows swiped away but still in the database stream. Dismissible needs
  // them out of the tree on the very next frame.
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = ref
        .watch(goalProgressProvider)
        .value
        ?.where((g) => g.goal.id == widget.goalId)
        .firstOrNull;
    if (progress == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final goal = progress.goal;
    final deposits = [
      for (final deposit
          in (ref.watch(goalDepositsProvider).value ?? const []).reversed)
        if (deposit.goalId == goal.id && !_dismissed.contains(deposit.id))
          deposit,
    ];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                BrutalIconButton(
                  icon: Icons.arrow_back_rounded,
                  semanticLabel: 'Back',
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(goal.title, style: AppText.h2)),
                BrutalIconButton(
                  key: const ValueKey('edit-goal'),
                  icon: Icons.edit_outlined,
                  semanticLabel: 'Edit goal',
                  onPressed: () => context.push('/goals/${goal.id}/edit'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Progress(progress: progress, today: now),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BrutalButton(
                    key: const ValueKey('add-money'),
                    label: 'Add money',
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: () => _addMoney(progress),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrutalButton(
                    key: const ValueKey('take-out'),
                    label: 'Take out',
                    icon: Icons.remove_rounded,
                    color: AppColors.white,
                    expand: true,
                    onPressed: progress.savedPaise > 0
                        ? () => _takeOut(progress)
                        : null,
                  ),
                ),
              ],
            ),
            // Nothing to plan once it's reached or its date has passed.
            if (!progress.reached && !progress.isMissed(now)) ...[
              const SizedBox(height: 28),
              const Text("Penny's plan", style: AppText.h2),
              const SizedBox(height: 12),
              PlanCard(progress: progress, today: now),
            ],
            const SizedBox(height: 28),
            const Text('Money in', style: AppText.h2),
            const SizedBox(height: 12),
            if (deposits.isEmpty)
              const Text('Nothing put aside yet.', style: AppText.bodyMuted)
            else
              BrutalCard(
                padding: EdgeInsets.zero,
                clipChild: true,
                child: Column(
                  children: [
                    for (final (i, deposit) in deposits.indexed) ...[
                      if (i > 0) const RowDivider(),
                      _DepositRow(
                        deposit: deposit,
                        onDelete: () => _deleteDeposit(deposit),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                key: const ValueKey('delete-goal'),
                onPressed: () => _deleteGoal(goal),
                child: const Text('Delete goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMoney(GoalProgress progress) async {
    final paise = await showAmountSheet(
      context,
      title: 'Add money',
      hint: 'Put toward ${progress.goal.title}.',
    );
    if (paise == null || paise <= 0) return;
    await ref.read(goalRepositoryProvider).deposit(progress.goal.id, paise);
    final reachedNow =
        !progress.reached &&
        progress.savedPaise + paise >= progress.goal.targetPaise;
    if (!mounted || !reachedNow) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(PennyMood.celebrating.line)));
  }

  Future<void> _takeOut(GoalProgress progress) async {
    final paise = await showAmountSheet(
      context,
      title: 'Take out',
      hint: 'Up to ${formatPaise(progress.savedPaise)}.',
      maxPaise: progress.savedPaise,
    );
    if (paise == null || paise <= 0) return;
    await ref.read(goalRepositoryProvider).deposit(progress.goal.id, -paise);
  }

  void _deleteDeposit(GoalDeposit deposit) {
    final repo = ref.read(goalRepositoryProvider);
    setState(() => _dismissed.add(deposit.id));
    repo.deleteDeposit(deposit.id);
    showUndoSnackBar(
      context,
      message: deposit.amountPaise > 0
          ? 'Money in removed'
          : 'Take-out removed',
      onUndo: () async {
        await repo.restoreDeposit(deposit.id);
        if (mounted) setState(() => _dismissed.remove(deposit.id));
      },
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: const Text(
          "The money you noted for it and Penny's plan go too.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-goal'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!(sure ?? false)) return;
    await ref.read(goalRepositoryProvider).delete(goal.id);
    if (mounted) context.pop();
  }
}

/// The big card at the top: Penny, what's saved, and what's still needed.
class _Progress extends StatelessWidget {
  const _Progress({required this.progress, required this.today});

  final GoalProgress progress;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final mood = progress.reached
        ? PennyMood.celebrating
        : progress.isMissed(today)
        ? PennyMood.worried
        : PennyMood.happy;
    return BrutalCard(
      key: const ValueKey('goal-progress'),
      color: progress.reached ? AppColors.sky : AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PennyMascot(mood: mood, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MoneyText(
                        progress.savedPaise,
                        style: AppText.hero,
                      ),
                    ),
                    Text(
                      'of ${formatPaise(goal.targetPaise)} by '
                      '${DateFormat('d MMM y').format(goal.deadline)}',
                      style: AppText.bodyStrong,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GoalProgressBar(progress: progress.progress),
          const SizedBox(height: 10),
          Text(goalNeedLine(progress, today), style: AppText.bodyStrong),
          if (!progress.reached && !progress.isMissed(today))
            Text(
              'About ${formatPaise(progress.perMonthPaise(today))} a month',
              style: AppText.small,
            ),
        ],
      ),
    );
  }
}

class _DepositRow extends StatelessWidget {
  const _DepositRow({required this.deposit, required this.onDelete});

  final GoalDeposit deposit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final amount = deposit.amountPaise;
    return Dismissible(
      key: ValueKey(deposit.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: AppColors.pink,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text('Delete', style: AppText.label),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    amount > 0 ? 'Put in' : 'Taken out',
                    style: AppText.label,
                  ),
                  Text(
                    DateFormat('d MMM y, h:mm a').format(deposit.occurredAt),
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            Text(
              amount > 0 ? '+${formatPaise(amount)}' : formatPaise(amount),
              style: AppText.label,
            ),
          ],
        ),
      ),
    );
  }
}
