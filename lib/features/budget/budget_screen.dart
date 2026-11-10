import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/category.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/widgets/amount_sheet.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/pressable_area.dart';

/// The budget: what the user means to spend on each category a month. The
/// monthly budget is their total; Penny's mood and the calendar go by its
/// everyday part.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(budgetStatusProvider);
    final repo = ref.read(budgetRepositoryProvider);

    Future<void> edit(Category category) async {
      final paise = await showAmountSheet(
        context,
        title: '${category.label} budget',
        hint: 'What you mean to spend on it each month.',
        initialPaise: status.budget.byCategory[category.id],
      );
      if (paise != null) await repo.setAmount(category.id, paise);
    }

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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Budget', style: AppText.h2),
                      Text(
                        'Penny keeps an eye on it for you.',
                        style: AppText.bodyMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Total(status: status),
            const SizedBox(height: 28),
            const Text('Budget by category', style: AppText.h2),
            const SizedBox(height: 4),
            const Text(
              'Give the categories you care about an amount. They add up to '
              'your monthly budget, and Penny watches the ones that have one.',
              style: AppText.small,
            ),
            const SizedBox(height: 12),
            BrutalCard(
              padding: EdgeInsets.zero,
              clipChild: true,
              child: Column(
                children: [
                  for (final (i, category) in spendCategories.indexed) ...[
                    if (i > 0) const RowDivider(),
                    _CategoryRow(
                      category: category,
                      spentPaise: status.spentIn(category.id),
                      amountPaise: status.budget.byCategory[category.id],
                      onTap: () => edit(category),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The monthly budget: the categories' total, and how the everyday part of
/// it is going.
class _Total extends StatelessWidget {
  const _Total({required this.status});

  final BudgetStatus status;

  @override
  Widget build(BuildContext context) {
    final budget = status.budget;
    final everyday = budget.everydayPaise;
    final spent = status.everydaySpentPaise;
    return BrutalCard(
      key: const ValueKey('monthly-budget'),
      color: AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly budget', style: AppText.label),
          const SizedBox(height: 4),
          if (budget.isEmpty) ...[
            const Text('Not set yet', style: AppText.h2),
            const SizedBox(height: 4),
            const Text(
              'Give the categories below a budget. They add up here.',
              style: AppText.bodyStrong,
            ),
          ] else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(budget.totalPaise, style: AppText.hero),
            ),
            Text(
              'Everyday ${formatPaise(everyday)} · Paid in one go '
              '${formatPaise(budget.oneGoPaise)}',
              key: const ValueKey('budget-split'),
              style: AppText.bodyStrong,
            ),
            if (everyday > 0) ...[
              const SizedBox(height: 12),
              Text(
                '${formatPaise(spent)} of ${formatPaise(everyday)} everyday '
                'spent · ${daysLeftLabel(status.daysLeft)}',
                style: AppText.small.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              _UsedBar(used: spent / everyday),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            oneGoLine,
            key: const ValueKey('budget-one-go'),
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.spentPaise,
    required this.amountPaise,
    required this.onTap,
  });

  final Category category;
  final int spentPaise;
  final int? amountPaise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amount = amountPaise;
    return PressableArea(
      key: ValueKey('budget-${category.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Text(
                category.emoji,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(category.label, style: AppText.label),
                  Text(
                    amount == null
                        ? '${formatPaise(spentPaise)} this month · no budget'
                        : '${formatPaise(spentPaise)} of ${formatPaise(amount)} '
                              'this month',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            Text(
              amount == null ? 'Add' : formatPaise(amount),
              style: AppText.chip,
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

/// How much of a budget is used, as a chunky bar. Past it, the bar is full
/// and pink.
class _UsedBar extends StatelessWidget {
  const _UsedBar({required this.used});

  final double used;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(kPillRadius),
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: math.min(1.0, used),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: used > 1 ? AppColors.pink : AppColors.ink,
            borderRadius: const BorderRadius.all(Radius.circular(kPillRadius)),
          ),
        ),
      ),
    );
  }
}
