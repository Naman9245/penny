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

/// The budget: what the user means to spend on everyday things each month,
/// and caps for single categories. Penny's mood and the calendar go by it.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(budgetStatusProvider);
    final repo = ref.read(budgetRepositoryProvider);

    Future<void> editEveryday() async {
      final paise = await showAmountSheet(
        context,
        title: 'Monthly budget',
        hint: 'What you mean to spend on everyday things each month.',
        initialPaise: status.budget.everydayPaise,
      );
      if (paise != null) await repo.setEveryday(paise);
    }

    Future<void> editCap(Category category) async {
      final paise = await showAmountSheet(
        context,
        title: '${category.label} cap',
        hint: 'The most you mean to spend on it each month.',
        initialPaise: status.budget.caps[category.id],
      );
      if (paise != null) await repo.setCap(category.id, paise);
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
            _Everyday(status: status, onTap: editEveryday),
            const SizedBox(height: 28),
            const Text('Caps', style: AppText.h2),
            const SizedBox(height: 4),
            const Text(
              'Optional limits for single categories, every month.',
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
                    _CapRow(
                      category: category,
                      spentPaise: status.spentIn(category.id),
                      capPaise: status.budget.caps[category.id],
                      onTap: () => editCap(category),
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

class _Everyday extends StatelessWidget {
  const _Everyday({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final budget = status.budget.everydayPaise;
    final spent = status.everydaySpentPaise;
    return BrutalCard(
      key: const ValueKey('everyday-budget'),
      color: AppColors.yellow,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Monthly budget', style: AppText.label),
              ),
              Text(budget == null ? 'Set' : 'Edit', style: AppText.chip),
              const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
            ],
          ),
          const SizedBox(height: 4),
          if (budget == null)
            const Text('Not set yet', style: AppText.h2)
          else ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(budget, style: AppText.hero),
            ),
            const SizedBox(height: 2),
            Text(
              '${formatPaise(spent)} spent this month · '
              '${daysLeftLabel(status.daysLeft)}',
              style: AppText.bodyStrong,
            ),
            const SizedBox(height: 10),
            _UsedBar(used: spent / budget),
          ],
          const SizedBox(height: 10),
          const Text(
            'For everyday spending. Rent & PG, Bills & recharge, '
            'Subscriptions and Education are paid in one go, so they stay '
            'out.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.category,
    required this.spentPaise,
    required this.capPaise,
    required this.onTap,
  });

  final Category category;
  final int spentPaise;
  final int? capPaise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cap = capPaise;
    return InkWell(
      key: ValueKey('cap-${category.id}'),
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
                    cap == null
                        ? '${formatPaise(spentPaise)} this month'
                        : '${formatPaise(spentPaise)} of ${formatPaise(cap)} '
                              'this month',
                    style: AppText.small,
                  ),
                ],
              ),
            ),
            Text(
              cap == null ? 'No cap' : formatPaise(cap),
              style: AppText.chip,
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
          ],
        ),
      ),
    );
  }
}

/// How much of a budget or cap is used, as a chunky bar.
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
