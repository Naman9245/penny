import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/transactions/txn_tile.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/penny_mascot.dart';

/// Penny's mood, this month at a glance, and the latest entries.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final month = monthStart(now);
    final mood = ref.watch(pennyMoodProvider);
    final summary = ref
        .watch(monthSummaryProvider(month))
        .when(
          data: (summary) => summary,
          loading: () => MonthSummary.empty,
          error: (error, stackTrace) => MonthSummary.empty,
        );
    final recent = ref.watch(recentTxnsProvider);

    return SafeArea(
      bottom: false,
      child: ListView(
        // Room at the bottom so the Add button never hides the last row.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          Text(_greeting(now), style: AppText.h1),
          const SizedBox(height: 2),
          Text(
            DateFormat('EEEE, d MMMM').format(now),
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 18),
          _PennyCard(mood: mood),
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
                    child: Text(
                      'Nothing logged yet. Tap Add, type the amount, then tap '
                      'a category.',
                      style: AppText.body,
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

class _PennyCard extends StatelessWidget {
  const _PennyCard({required this.mood});

  final PennyMood mood;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      color: mood.color,
      padding: const EdgeInsets.fromLTRB(10, 12, 16, 12),
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
                Text(mood.line, style: AppText.h3),
              ],
            ),
          ),
        ],
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
                  label: 'Got',
                  color: AppColors.mint,
                  value: MoneyText(summary.gotPaise, style: AppText.amount),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _StatCard(
                  label: 'Left',
                  color: AppColors.yellow,
                  value: summary.hasIncome
                      ? MoneyText(summary.leftPaise, style: AppText.amount)
                      : const Text('—', style: AppText.amount),
                  hint: summary.hasIncome ? null : 'Log income to see this',
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
