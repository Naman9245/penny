import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/services/report_math.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/meter_bar.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/flat_section.dart';

// The Money report's own sections: where the money went, the months
// before, and when it goes. Every number is worked out on the phone, so
// they show with or without Penny's AI.

/// A section's title, with room above it.
class ReportSection extends StatelessWidget {
  const ReportSection(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.h2),
          if (subtitle case final text?) Text(text, style: AppText.small),
        ],
      ),
    );
  }
}

/// Where every rupee went: the month's totals, each category, the shops
/// and people paid most, and the biggest single spends.
class WhereMoneyWent extends StatelessWidget {
  const WhereMoneyWent({
    super.key,
    required this.report,
    required this.month,
    required this.everydayPaise,
  });

  final MoneyReport report;
  final DateTime month;

  /// The everyday budget, to explain the daily share; 0 with no budget.
  final int everydayPaise;

  @override
  Widget build(BuildContext context) {
    final totals = report.totals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReportSection('Where every rupee went'),
        FlatSection(
          key: const ValueKey('facts-totals'),
          child: Column(
            children: [
              _AmountRow(
                'Money in',
                wholeRupees(totals.gotPaise),
                type: TxnType.credit,
              ),
              _AmountRow(
                'Spent',
                wholeRupees(totals.spentPaise),
                type: TxnType.debit,
              ),
              if (totals.investedPaise > 0)
                _AmountRow('Invested', wholeRupees(totals.investedPaise)),
              const Divider(height: 18, color: AppColors.hairline),
              _AmountRow('Left', wholeRupees(totals.leftPaise), strong: true),
            ],
          ),
        ),
        if (everydayPaise > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Your share each day, '
            '${formatTotal(dailySharePaise(everydayPaise, month))}: '
            '${shareExplained(everydayPaise, month)}',
            key: const ValueKey('facts-share'),
            style: AppText.small,
          ),
        ],
        if (report.categories.isEmpty) ...[
          const SizedBox(height: 12),
          const Text('No spends this month yet.', style: AppText.bodyMuted),
        ] else ...[
          const SizedBox(height: 16),
          const Text('By category', style: AppText.h3),
          const SizedBox(height: 8),
          FlatSection(
            key: const ValueKey('facts-categories'),
            child: Column(
              children: [
                for (final (i, share) in report.categories.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _CategoryRow(share: share),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Paid most', style: AppText.h3),
          const SizedBox(height: 8),
          FlatSection(
            key: const ValueKey('facts-shops'),
            child: Column(
              children: [
                for (final (i, shop) in report.shops.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _LineRow(
                    title: shop.name,
                    detail: [
                      if (shop.isPerson) 'Person',
                      shop.count == 1 ? 'once' : '${shop.count} times',
                    ].join(' · '),
                    paise: wholeRupees(shop.paidPaise),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Biggest spends', style: AppText.h3),
          const SizedBox(height: 8),
          FlatSection(
            key: const ValueKey('facts-biggest'),
            child: Column(
              children: [
                for (final (i, spend) in report.biggest.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _LineRow(
                    title: spend.name,
                    detail:
                        '${DateFormat('d MMM, h:mm a').format(spend.at)} · '
                        '${categoryById(spend.categoryId).label}',
                    paise: spend.paise,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The months before: each month's money, how categories moved against
/// last month, new shops, and what's been kept so far.
class MoneyHistory extends StatelessWidget {
  const MoneyHistory({super.key, required this.report});

  final MoneyReport report;

  @override
  Widget build(BuildContext context) {
    final history = report.history;
    final first = history.length < 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReportSection(
          'Your history',
          subtitle: first
              ? 'Your first month with Penny. Each month adds to this.'
              : 'The last ${history.length} months',
        ),
        FlatSection(
          key: const ValueKey('facts-history'),
          child: Column(
            children: [
              for (final (i, line) in history.reversed.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                _LineRow(
                  title: DateFormat('MMMM yyyy').format(line.month),
                  detail:
                      'Spent ${formatTotal(line.spentPaise)} · '
                      'got ${formatTotal(line.gotPaise)}',
                  paise: wholeRupees(line.leftPaise),
                  signed: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        BrutalCard(
          key: const ValueKey('facts-saved'),
          color: report.savedSoFarPaise < 0 ? AppColors.pink : AppColors.mint,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.savedSoFarPaise < 0
                          ? 'Spent more than came in'
                          : 'Kept so far',
                      style: AppText.bodyStrong,
                    ),
                    const Text(
                      "Every month's Left, added up",
                      style: AppText.small,
                    ),
                  ],
                ),
              ),
              MoneyText(wholeRupees(report.savedSoFarPaise), style: AppText.h3),
            ],
          ),
        ),
        if (report.changes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Against last month', style: AppText.h3),
          const SizedBox(height: 8),
          FlatSection(
            key: const ValueKey('facts-changes'),
            child: Column(
              children: [
                for (final (i, change) in report.changes.take(8).indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ChangeRow(change: change),
                ],
              ],
            ),
          ),
        ],
        if (report.newShops.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('New this month', style: AppText.h3),
          const SizedBox(height: 8),
          FlatSection(
            key: const ValueKey('facts-new'),
            child: Text(
              'First time paying ${report.newShops.join(', ')}.',
              style: AppText.body,
            ),
          ),
        ],
      ],
    );
  }
}

/// When the money goes: by day of the week, by time of day, weekend
/// against weekday, and the small spends that add up.
class SpendingPatterns extends StatelessWidget {
  const SpendingPatterns({super.key, required this.report});

  final MoneyReport report;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    if (report.totals.spentPaise <= 0) return const SizedBox.shrink();
    final p = report.patterns;
    final dayMax = p.byWeekdayPaise.fold(0, (a, b) => a > b ? a : b);
    final partMax = p.byPartPaise.values.fold(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReportSection('Your patterns'),
        FlatSection(
          key: const ValueKey('facts-patterns'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('By day of the week', style: AppText.bodyStrong),
              const SizedBox(height: 8),
              for (final (i, paise) in p.byWeekdayPaise.indexed)
                _BarRow(
                  label: _days[i],
                  paise: paise,
                  of: dayMax,
                  // The weekend stands out from the week.
                  color: i >= 5 ? AppColors.headphones : AppColors.ink,
                ),
              const SizedBox(height: 14),
              const Text('By time of day', style: AppText.bodyStrong),
              const SizedBox(height: 8),
              for (final part in DayPart.values)
                _BarRow(
                  label: part.label,
                  detail: part.hours,
                  paise: p.byPartPaise[part] ?? 0,
                  of: partMax,
                  // Late nights stand out: it's when small spends slip by.
                  color: part == DayPart.lateNight
                      ? AppColors.chartSpent
                      : AppColors.ink,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Average(
                key: const ValueKey('facts-weekday'),
                label: 'A weekday',
                paise: p.weekdayAveragePaise,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Average(
                key: const ValueKey('facts-weekend'),
                label: 'A weekend day',
                paise: p.weekendAveragePaise,
              ),
            ),
          ],
        ),
        if (p.smallCount > 0) ...[
          const SizedBox(height: 12),
          BrutalCard(
            key: const ValueKey('facts-small'),
            color: AppColors.cream,
            child: Text(
              p.smallCount == 1
                  ? '1 small spend under ₹100 came to '
                        '${formatTotal(p.smallPaise)}.'
                  : '${p.smallCount} small spends under ₹100 added up to '
                        '${formatTotal(p.smallPaise)}.',
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ],
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow(this.label, this.paise, {this.type, this.strong = false});

  final String label;
  final int paise;
  final TxnType? type;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: strong ? AppText.bodyStrong : AppText.body,
            ),
          ),
          MoneyText(
            paise,
            type: paise == 0 ? null : type,
            style: strong ? AppText.h3 : AppText.bodyStrong,
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.share});

  final CategoryShare share;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(share.categoryId);
    final percent = (share.share * 100).round();
    final detail = [
      '$percent%',
      share.count == 1 ? '1 entry' : '${share.count} entries',
      if (share.topShop case final shop? when shop != category.label)
        'mostly $shop',
    ].join(' · ');
    return Column(
      key: ValueKey('facts-category-${share.categoryId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(category.icon, size: 18, color: AppColors.ink),
            const SizedBox(width: 8),
            Expanded(child: Text(category.label, style: AppText.bodyStrong)),
            MoneyText(wholeRupees(share.spentPaise), style: AppText.bodyStrong),
          ],
        ),
        const SizedBox(height: 6),
        MeterBar(value: share.share),
        const SizedBox(height: 2),
        Text(detail, style: AppText.small),
      ],
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.title,
    required this.detail,
    required this.paise,
    this.signed = false,
  });

  final String title;
  final String detail;
  final int paise;

  /// Shown as money kept (or lost), not paid.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppText.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(detail, style: AppText.small),
            ],
          ),
        ),
        const SizedBox(width: 8),
        MoneyText(
          paise,
          type: signed && paise > 0 ? TxnType.credit : null,
          style: AppText.bodyStrong,
        ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final CategoryChange change;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(change.categoryId);
    final diff = change.nowPaise - change.beforePaise;
    final up = diff > 0;
    final what = change.beforePaise == 0
        ? 'Nothing last month'
        : change.nowPaise == 0
        ? 'Nothing this month, ${formatTotal(change.beforePaise)} last month'
        : '${up ? 'Up' : 'Down'} ${formatTotal(diff.abs())} '
              '(${up ? '+' : '−'}${(diff.abs() * 100 / change.beforePaise).round()}%) '
              'from ${formatTotal(change.beforePaise)}';
    return Row(
      children: [
        Icon(
          up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 18,
          color: up ? AppColors.negative : AppColors.positive,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(category.label, style: AppText.bodyStrong),
              Text(what, style: AppText.small),
            ],
          ),
        ),
        MoneyText(wholeRupees(change.nowPaise), style: AppText.bodyStrong),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.paise,
    required this.of,
    required this.color,
    this.detail,
  });

  final String label;
  final String? detail;
  final int paise;
  final int of;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.body),
                if (detail case final hours?) Text(hours, style: AppText.small),
              ],
            ),
          ),
          Expanded(
            child: MeterBar(value: of <= 0 ? 0 : paise / of, color: color),
          ),
          SizedBox(
            width: 84,
            child: Text(
              formatTotal(paise),
              style: AppText.small.copyWith(color: AppColors.ink),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Average extends StatelessWidget {
  const _Average({super.key, required this.label, required this.paise});

  final String label;
  final int paise;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.small),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(wholeRupees(paise), style: AppText.h3),
          ),
          const Text('spent on average', style: AppText.small),
        ],
      ),
    );
  }
}
