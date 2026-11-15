import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/router/tab_months.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/analysis_totals.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/card_title.dart';
import 'package:penny/widgets/category_avatar.dart';
import 'package:penny/widgets/first_show.dart';
import 'package:penny/widgets/meter_bar.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/month_switcher.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/pressable_area.dart';
import 'package:penny/widgets/stat_tile.dart';
import 'package:penny/widgets/tag_split_bar.dart';

/// Where a month's money went and came from, category by category, biggest
/// first, and the six months up to it side by side.
class AnalysisScreen extends ConsumerStatefulWidget {
  const AnalysisScreen({super.key});

  @override
  ConsumerState<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends ConsumerState<AnalysisScreen> {
  @override
  Widget build(BuildContext context) {
    final month = ref.watch(analysisMonthProvider);
    final summary = ref
        .watch(monthSummaryProvider(month))
        .when(
          data: (summary) => summary,
          loading: () => MonthSummary.empty,
          error: (error, stackTrace) => MonthSummary.empty,
        );
    final totals = ref
        .watch(categoryTotalsProvider(month))
        .when(
          data: (totals) => totals,
          loading: () => const <CategoryTotal>[],
          error: (error, stackTrace) => const <CategoryTotal>[],
        );
    final months = ref
        .watch(monthlyTotalsProvider(month))
        .when(
          data: (months) => months,
          loading: () => const <MonthTotals>[],
          error: (error, stackTrace) => const <MonthTotals>[],
        );
    List<CategoryTotal> of(MoneyKind kind) => [
      for (final t in totals)
        if (t.kind == kind) t,
    ];
    final spent = of(MoneyKind.spent);
    final got = of(MoneyKind.got);
    final invested = of(MoneyKind.invested);
    final budgets =
        ref.watch(budgetProvider).value?.byCategory ?? const <String, int>{};

    return SafeArea(
      bottom: false,
      child: FirstShowScope(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Analysis', style: AppText.h1),
            const SizedBox(height: 14),
            MonthSwitcher(
              month: month,
              onChanged: ref.read(analysisMonthProvider.notifier).show,
            ),
            const SizedBox(height: 18),
            if (totals.isEmpty)
              const _NothingYet()
            else ...[
              Entrance(
                id: 'totals',
                child: _Totals(summary: summary),
              ),
              if (spent.isNotEmpty) ...[
                const SizedBox(height: 16),
                Entrance(
                  id: 'split',
                  index: 1,
                  child: _SplitCard(month: month),
                ),
                const SizedBox(height: 28),
                Entrance(
                  id: 'spent',
                  index: 2,
                  child: _Ranked(
                    title: 'Where it went',
                    totals: spent,
                    outOf: summary.spentPaise,
                    month: month,
                    budgets: budgets,
                  ),
                ),
              ],
              if (got.isNotEmpty) ...[
                const SizedBox(height: 28),
                _Ranked(
                  title: 'Where it came from',
                  totals: got,
                  outOf: summary.gotPaise,
                  month: month,
                ),
              ],
              if (invested.isNotEmpty) ...[
                const SizedBox(height: 28),
                // As a share of what came in, when anything did.
                _Ranked(
                  title: 'Put away',
                  totals: invested,
                  outOf: summary.gotPaise,
                  month: month,
                ),
              ],
            ],
            const SizedBox(height: 28),
            const Text('Last 6 months', style: AppText.h2),
            const SizedBox(height: 12),
            _MonthsChart(months: months),
          ],
        ),
      ),
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) {
    return const BrutalCard(
      color: AppColors.lavender,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          PennyMascot(size: 72),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add a few entries to see where your money goes.',
              style: AppText.h3,
            ),
          ),
        ],
      ),
    );
  }
}

/// The month's money out, in and left, side by side in one card.
class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.fromLTRB(14, 12, 10, 14);
    return BrutalCard(
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.north_east_rounded,
                color: AppColors.pink,
                label: 'Spent',
                padding: padding,
                value: MoneyText(
                  wholeRupees(summary.spentPaise),
                  style: AppText.amount,
                ),
              ),
            ),
            const StatDivider(),
            Expanded(
              child: StatTile(
                icon: Icons.south_west_rounded,
                color: AppColors.mint,
                label: 'Got',
                padding: padding,
                value: MoneyText(
                  wholeRupees(summary.gotPaise),
                  style: AppText.amount,
                ),
              ),
            ),
            const StatDivider(),
            Expanded(
              child: StatTile(
                icon: Icons.account_balance_wallet_outlined,
                color: AppColors.yellow,
                label: 'Left',
                padding: padding,
                value: summary.hasIncome
                    ? MoneyText(
                        wholeRupees(summary.leftPaise),
                        style: AppText.amount,
                      )
                    : const Text('—', style: AppText.amount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The month's spending by necessary and wasteful, and the way into Penny's
/// report.
class _SplitCard extends ConsumerWidget {
  const _SplitCard({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = ref.watch(tagSplitProvider(month)).value;
    final hasReport = ref.watch(insightProvider(month)).value != null;
    if (split == null) return const SizedBox.shrink();
    return BrutalCard(
      key: const ValueKey('split-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CardTitle(
            icon: Icons.balance_rounded,
            color: AppColors.lavender,
            title: 'Necessary vs wasteful',
          ),
          const SizedBox(height: 14),
          TagSplitBar(split: split),
          const SizedBox(height: 10),
          TagSplitKey(split: split),
          const SizedBox(height: 14),
          BrutalButton(
            key: const ValueKey('open-report'),
            label: 'Money report',
            icon: hasReport
                ? Icons.receipt_long_rounded
                : Icons.auto_awesome_rounded,
            expand: true,
            onPressed: () => context.push(reportLocation(month)),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalChip(
                key: const ValueKey('open-needs'),
                label: 'Edit my needs',
                icon: Icons.tune_rounded,
                onTap: () => context.push('/needs'),
              ),
              BrutalChip(
                key: const ValueKey('open-budget'),
                label: 'Budget',
                icon: Icons.savings_outlined,
                onTap: () => context.push('/budget'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Categories biggest first, each with its share of [outOf] as a bar, in
/// one card. A row opens that category's entries.
class _Ranked extends StatelessWidget {
  const _Ranked({
    required this.title,
    required this.totals,
    required this.outOf,
    required this.month,
    this.budgets = const {},
  });

  final String title;
  final List<CategoryTotal> totals;

  /// The month's total the shares are taken of.
  final int outOf;
  final DateTime month;

  /// Category id → what the user means to spend on it a month.
  final Map<String, int> budgets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppText.h2),
        const SizedBox(height: 12),
        BrutalCard(
          padding: EdgeInsets.zero,
          clipChild: true,
          child: Column(
            children: [
              for (final (i, total) in totals.indexed) ...[
                if (i > 0) const RowDivider(),
                _CategoryRow(
                  total: total,
                  outOf: outOf,
                  month: month,
                  budget: budgets[total.categoryId],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.total,
    required this.outOf,
    required this.month,
    this.budget,
  });

  final CategoryTotal total;
  final int outOf;
  final DateTime month;

  /// What the user means to spend on it a month, if anything.
  final int? budget;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(total.categoryId);
    final share = outOf <= 0 ? 0.0 : total.totalPaise / outOf;
    final budget = this.budget;
    final over = budget != null && total.totalPaise > budget;
    final cameBack = total.paidBackPaise;
    final detail = switch (budget) {
      null when total.count == 1 => '1 entry',
      null => '${total.count} entries',
      final limit when total.totalPaise > limit =>
        '${formatPaise(total.totalPaise - limit)} over budget',
      final limit =>
        '${formatPaise(limit - total.totalPaise)} left of '
            '${formatPaise(limit)}',
    };
    return PressableArea(
      key: ValueKey('category-card-${category.id}'),
      onTap: () => context.push(txnsLocation(month, categoryId: category.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            CategoryAvatar(category: category, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.label,
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      MoneyText(
                        total.totalPaise,
                        style: AppText.h3,
                        tabular: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: MeterBar(value: share)),
                      SizedBox(
                        width: 44,
                        child: Text(
                          '${(share * 100).round()}%',
                          style: AppText.chip,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (over)
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: AppColors.negative,
                        ),
                      Text(
                        detail,
                        key: budget == null
                            ? null
                            : ValueKey('budget-status-${category.id}'),
                        style: over
                            ? AppText.small.copyWith(
                                color: AppColors.negative,
                                fontWeight: FontWeight.w700,
                              )
                            : AppText.small,
                      ),
                      if (cameBack > 0) ...[
                        const Text('·', style: AppText.small),
                        Text(
                          '${formatPaise(cameBack)} came back',
                          key: ValueKey('came-back-${category.id}'),
                          style: AppText.small,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Got and spent for six months, as pairs of bars.
class _MonthsChart extends StatelessWidget {
  const _MonthsChart({required this.months});

  final List<MonthTotals> months;

  @override
  Widget build(BuildContext context) {
    final top = months.fold(
      0,
      (most, m) => math.max(most, math.max(m.spentPaise, m.gotPaise)),
    );
    return BrutalCard(
      padding: const EdgeInsets.fromLTRB(8, 18, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: top == 0
                ? const Center(
                    child: Text(
                      'Nothing to compare yet.',
                      style: AppText.bodyMuted,
                    ),
                  )
                : BarChart(_data(top)),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.chartGot, label: 'Got'),
              SizedBox(width: 18),
              _Legend(color: AppColors.chartSpent, label: 'Spent'),
            ],
          ),
        ],
      ),
    );
  }

  BarChartData _data(int top) {
    final maxY = _niceCeiling(top * 1.1);
    final step = maxY / 4;
    return BarChartData(
      maxY: maxY,
      alignment: BarChartAlignment.spaceAround,
      borderData: FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: AppColors.hairline, width: 1.5),
        ),
      ),
      gridData: FlGridData(
        drawVerticalLine: false,
        horizontalInterval: step,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.hairline, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 58,
            interval: step,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(compactRupees(value.round()), style: AppText.small),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                DateFormat('MMM').format(months[value.toInt()].month),
                // The month on show stands out from the ones before.
                style: value.toInt() == months.length - 1
                    ? AppText.small.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      )
                    : AppText.small,
              ),
            ),
          ),
        ),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppColors.ink,
          getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
            '${rodIndex == 0 ? 'Got' : 'Spent'} ${formatPaise(rod.toY.round())}',
            AppText.chip.copyWith(color: AppColors.cream),
          ),
        ),
      ),
      barGroups: [
        for (var i = 0; i < months.length; i++)
          BarChartGroupData(
            x: i,
            barsSpace: 3,
            barRods: [
              _rod(months[i].gotPaise, AppColors.chartGot),
              _rod(months[i].spentPaise, AppColors.chartSpent),
            ],
          ),
      ],
    );
  }

  static BarChartRodData _rod(int paise, Color color) => BarChartRodData(
    toY: paise.toDouble(),
    color: color,
    width: 12,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
  );

  /// The next round figure at or above [value]: 1, 2, 2.5 or 5 times a
  /// power of ten, so the axis reads ₹2.5K, ₹5K, ₹7.5K, ₹10K.
  static double _niceCeiling(double value) {
    final magnitude = math
        .pow(10, (math.log(value) / math.ln10).floor())
        .toDouble();
    for (final step in const [1.0, 2.0, 2.5, 5.0]) {
      if (step * magnitude >= value) return step * magnitude;
    }
    return 10 * magnitude;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.chip),
      ],
    );
  }
}
