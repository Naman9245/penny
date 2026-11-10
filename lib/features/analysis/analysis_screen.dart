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
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/analysis_totals.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/month_switcher.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/tag_split_bar.dart';

/// Where a month's money went and came from, one card per category, and the
/// six months up to it side by side.
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
            _Totals(summary: summary),
            if (spent.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SplitCard(month: month),
              const SizedBox(height: 28),
              const Text('Where it went', style: AppText.h2),
              const SizedBox(height: 12),
              _CategoryCards(
                totals: spent,
                outOf: summary.spentPaise,
                month: month,
                budgets: budgets,
              ),
            ],
            if (got.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Where it came from', style: AppText.h2),
              const SizedBox(height: 12),
              _CategoryCards(
                totals: got,
                outOf: summary.gotPaise,
                month: month,
              ),
            ],
            if (invested.isNotEmpty) ...[
              const SizedBox(height: 28),
              const Text('Put away', style: AppText.h2),
              const SizedBox(height: 12),
              // As a share of what came in, when anything did.
              _CategoryCards(
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

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int paise, Color color) => Expanded(
      child: BrutalCard(
        color: color,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppText.label),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: MoneyText(paise, style: AppText.amount),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        stat('Spent', summary.spentPaise, AppColors.pink),
        const SizedBox(width: 14),
        stat('Got', summary.gotPaise, AppColors.mint),
      ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Necessary vs wasteful', style: AppText.h3),
          const SizedBox(height: 12),
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

/// Category cards, two to a row, biggest first.
class _CategoryCards extends StatelessWidget {
  const _CategoryCards({
    required this.totals,
    required this.outOf,
    required this.month,
    this.budgets = const {},
  });

  final List<CategoryTotal> totals;

  /// The month's total the shares are taken of.
  final int outOf;
  final DateTime month;

  /// Category id → what the user means to spend on it a month.
  final Map<String, int> budgets;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < totals.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 14),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _card(context, totals[i])),
                const SizedBox(width: 14),
                Expanded(
                  child: i + 1 < totals.length
                      ? _card(context, totals[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, CategoryTotal total) {
    final category = categoryById(total.categoryId);
    final share = outOf <= 0 ? 0.0 : total.totalPaise / outOf;
    final budget = budgets[category.id];
    final cameBack = total.paidBackPaise;
    return BrutalCard(
      key: ValueKey('category-card-${category.id}'),
      color: category.color,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      onTap: () => context.push(txnsLocation(month, categoryId: category.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Text(
                  category.emoji,
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 30, height: 1.15),
                ),
              ),
              const Spacer(),
              if (outOf > 0)
                Text('${(share * 100).round()}%', style: AppText.chip),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            category.label,
            style: AppText.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(total.totalPaise, style: AppText.amount),
          ),
          Text(switch (budget) {
            null when total.count == 1 => '1 entry',
            null => '${total.count} entries',
            final limit when total.totalPaise > limit =>
              '${formatPaise(total.totalPaise - limit)} over budget',
            final limit => 'of ${formatPaise(limit)}',
          }, style: AppText.small.copyWith(color: AppColors.ink)),
          if (cameBack > 0)
            Text(
              '${formatPaise(cameBack)} came back',
              key: ValueKey('came-back-${category.id}'),
              style: AppText.small.copyWith(color: AppColors.ink),
            ),
          const Spacer(),
          const SizedBox(height: 10),
          // With a budget, the bar shows how much of it is used.
          if (budget != null)
            _ShareBar(
              key: ValueKey('budget-bar-${category.id}'),
              share: total.totalPaise / budget,
            )
          else
            _ShareBar(share: share),
        ],
      ),
    );
  }
}

/// How much of the month, or of its budget, this category is, as a chunky
/// bar. Past its budget the bar is full and pink.
class _ShareBar extends StatelessWidget {
  const _ShareBar({super.key, required this.share});

  final double share;

  @override
  Widget build(BuildContext context) {
    return Container(
      // The whole card's width, so the empty part of the track shows.
      width: double.infinity,
      height: 12,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(kPillRadius),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: math.min(1.0, share),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: share > 1 ? AppColors.pink : AppColors.ink,
            borderRadius: const BorderRadius.all(Radius.circular(kPillRadius)),
          ),
        ),
      ),
    );
  }
}

/// Got and spent for six months, as pairs of bordered bars.
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
              _Legend(color: AppColors.mint, label: 'Got'),
              SizedBox(width: 18),
              _Legend(color: AppColors.pink, label: 'Spent'),
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
      borderData: FlBorderData(show: false),
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
            reservedSize: 48,
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
                style: AppText.small,
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
            barsSpace: 4,
            barRods: [
              _rod(months[i].gotPaise, AppColors.mint),
              _rod(months[i].spentPaise, AppColors.pink),
            ],
          ),
      ],
    );
  }

  static BarChartRodData _rod(int paise, Color color) => BarChartRodData(
    toY: paise.toDouble(),
    color: color,
    width: 12,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
    borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.ink, width: 1.5),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppText.chip),
      ],
    );
  }
}
