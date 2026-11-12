import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/card_title.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// The days of a month the card shows on.
const fixedBillsDays = 7;

/// Last month's fixed bill, not logged yet this month.
typedef FixedBill = ({
  String key,
  String categoryId,
  String? place,
  int amountPaise,
});

/// Which bill an entry is: its category and place.
String fixedBillKey(Txn txn) =>
    '${txn.categoryId}|${(txn.merchant ?? '').trim().toLowerCase()}';

bool _isFixed(Txn txn) => txn.isSpend && categoryById(txn.categoryId).oneGo;

/// Rent, bills, subscriptions and education from [lastMonth] that
/// [thisMonth] has nothing for yet, same category and place, leaving out
/// [skipped]. Each at its latest amount, biggest first.
List<FixedBill> fixedBillsDue(
  Iterable<Txn> lastMonth,
  Iterable<Txn> thisMonth, {
  Set<String> skipped = const {},
}) {
  final logged = {
    for (final txn in thisMonth)
      if (_isFixed(txn)) fixedBillKey(txn),
  };
  final latest = <String, Txn>{};
  for (final txn in lastMonth) {
    if (!_isFixed(txn)) continue;
    final key = fixedBillKey(txn);
    final seen = latest[key];
    if (seen == null || txn.occurredAt.isAfter(seen.occurredAt)) {
      latest[key] = txn;
    }
  }
  return [
    for (final MapEntry(:key, value: txn) in latest.entries)
      if (!logged.contains(key) && !skipped.contains(key))
        (
          key: key,
          categoryId: txn.categoryId,
          place: switch (txn.merchant?.trim()) {
            final place? when place.isNotEmpty => place,
            _ => null,
          },
          amountPaise: txn.amountPaise,
        ),
  ]..sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
}

final _skippedBillsProvider = StreamProvider.autoDispose
    .family<Set<String>, DateTime>(
      (ref, month) =>
          ref.watch(prefsRepositoryProvider).watchSkippedBills(month),
    );

/// This month's fixed bills still to log, in its first week. Empty the rest
/// of the month, and until everything it needs has loaded.
final fixedBillsDueProvider = Provider.autoDispose<List<FixedBill>>((ref) {
  final today = ref.watch(todayProvider);
  if (today.day > fixedBillsDays) return const [];
  final month = monthStart(today);
  final last = ref.watch(
    monthTxnsProvider(DateTime(month.year, month.month - 1)),
  );
  final now = ref.watch(monthTxnsProvider(month));
  final skipped = ref.watch(_skippedBillsProvider(month));
  return switch ((last.value, now.value, skipped.value)) {
    (final last?, final now?, final skipped?) => fixedBillsDue(
      last,
      now,
      skipped: skipped,
    ),
    _ => const [],
  };
});

/// "Same fixed bills as last month?": last month's rent, bills,
/// subscriptions and education, a tap from logged again. Shown in a month's
/// first week while any is left.
class FixedBillsCard extends ConsumerWidget {
  const FixedBillsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(fixedBillsDueProvider);
    if (bills.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: BrutalCard(
        key: const ValueKey('fixed-bills'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CardTitle(
              icon: Icons.receipt_long_rounded,
              color: AppColors.yellow,
              title: 'Same fixed bills as last month?',
              subtitle: 'Log one to add it today, or skip it for this month.',
            ),
            for (final (i, bill) in bills.indexed) ...[
              const SizedBox(height: 10),
              _BillRow(
                index: i,
                bill: bill,
                onLog: () => _log(context, ref, bill),
                onSkip: () => ref
                    .read(prefsRepositoryProvider)
                    .skipBill(monthStart(ref.read(todayProvider)), bill.key),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _log(BuildContext context, WidgetRef ref, FixedBill bill) async {
    final repo = ref.read(txnRepositoryProvider);
    final id = await repo.add(
      amountPaise: bill.amountPaise,
      type: TxnType.debit,
      categoryId: bill.categoryId,
      occurredAt: onDay(ref.read(todayProvider), clock.now()),
      merchant: bill.place,
    );
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message:
          'Added ${formatPaise(bill.amountPaise)} · '
          '${categoryById(bill.categoryId).label}',
      onUndo: () => repo.softDelete(id),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.index,
    required this.bill,
    required this.onLog,
    required this.onSkip,
  });

  final int index;
  final FixedBill bill;
  final VoidCallback onLog;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(bill.categoryId);
    return Row(
      children: [
        Expanded(
          child: Text(
            '${category.emoji} ${bill.place ?? category.label} · '
            '${formatPaise(bill.amountPaise)}',
            key: ValueKey('bill-$index'),
            style: AppText.bodyStrong,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        BrutalChip(
          key: ValueKey('log-bill-$index'),
          label: 'Log',
          icon: Icons.add_rounded,
          onTap: onLog,
        ),
        const SizedBox(width: 6),
        BrutalChip(
          key: ValueKey('skip-bill-$index'),
          label: 'Skip',
          onTap: onSkip,
        ),
      ],
    );
  }
}
