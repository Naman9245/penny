import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/transactions/txn_tile.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/month_switcher.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

enum _Filter {
  all('All'),
  spent('Spent'),
  got('Got');

  const _Filter(this.label);

  final String label;

  bool keeps(Txn txn) => switch (this) {
    _Filter.all => true,
    _Filter.spent => txn.type == TxnType.debit,
    _Filter.got => txn.type == TxnType.credit,
  };
}

/// Every entry in a month, grouped by day. Swipe left to delete, tap to edit.
/// Opened from an Analysis card, it starts on that month and category.
class TxnListScreen extends ConsumerStatefulWidget {
  const TxnListScreen({super.key, this.initialMonth, this.categoryId});

  final DateTime? initialMonth;

  /// Show only this category, until its chip is tapped away.
  final String? categoryId;

  @override
  ConsumerState<TxnListScreen> createState() => _TxnListScreenState();
}

class _TxnListScreenState extends ConsumerState<TxnListScreen> {
  late DateTime _month = widget.initialMonth ?? monthStart(DateTime.now());
  late String? _categoryId = widget.categoryId;
  _Filter _filter = _Filter.all;

  // Rows swiped away but still in the database stream. Dismissible needs
  // them out of the tree on the very next frame.
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final txns = ref.watch(monthTxnsProvider(_month));
    final categoryId = _categoryId;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  BrutalIconButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Back',
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Transactions',
                      style: AppText.h1,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: MonthSwitcher(
                month: _month,
                onChanged: (month) => setState(() => _month = month),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in _Filter.values)
                    BrutalChip(
                      label: filter.label,
                      selected: filter == _filter,
                      onTap: () => setState(() => _filter = filter),
                    ),
                  if (categoryId != null)
                    BrutalChip(
                      key: const ValueKey('category-filter'),
                      label: categoryById(categoryId).label,
                      icon: Icons.close_rounded,
                      selected: true,
                      selectedColor: categoryById(categoryId).color,
                      onTap: () => setState(() => _categoryId = null),
                    ),
                ],
              ),
            ),
            Expanded(
              child: txns.when(
                data: _days,
                loading: () => const SizedBox.shrink(),
                error: (error, stackTrace) => Center(
                  child: Text(
                    "Couldn't load entries: $error",
                    style: AppText.body,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _days(List<Txn> all) {
    final visible = [
      for (final txn in all)
        if (!_dismissed.contains(txn.id) &&
            _filter.keeps(txn) &&
            (_categoryId == null || txn.categoryId == _categoryId))
          txn,
    ];
    if (visible.isEmpty) return _EmptyMonth(month: _month, filter: _filter);

    final byDay = <DateTime, List<Txn>>{};
    for (final txn in visible) {
      byDay.putIfAbsent(dayStart(txn.occurredAt), () => []).add(txn);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        for (final MapEntry(key: day, value: txns) in byDay.entries) ...[
          _DayHeader(day: day, txns: txns),
          const SizedBox(height: 8),
          BrutalCard(
            padding: EdgeInsets.zero,
            clipChild: true,
            child: Column(
              children: [
                for (var i = 0; i < txns.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  _Swipeable(txn: txns[i], onDelete: _delete),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  void _delete(Txn txn) {
    final repo = ref.read(txnRepositoryProvider);
    setState(() => _dismissed.add(txn.id));
    repo.softDelete(txn.id);
    showUndoSnackBar(
      context,
      message:
          'Deleted ${formatPaise(txn.amountPaise)} · '
          '${categoryById(txn.categoryId).label}',
      onUndo: () {
        repo.restore(txn.id);
        if (mounted) setState(() => _dismissed.remove(txn.id));
      },
    );
  }
}

class _Swipeable extends StatelessWidget {
  const _Swipeable({required this.txn, required this.onDelete});

  final Txn txn;
  final ValueChanged<Txn> onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(txn.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(txn),
      background: Container(
        color: AppColors.pink,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete', style: AppText.label),
            SizedBox(width: 6),
            Icon(Icons.delete_outline_rounded, color: AppColors.ink),
          ],
        ),
      ),
      child: TxnTile(txn: txn, onTap: () => context.push('/txns/${txn.id}')),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.txns});

  final DateTime day;
  final List<Txn> txns;

  @override
  Widget build(BuildContext context) {
    var spent = 0;
    var got = 0;
    for (final txn in txns) {
      switch (txn.type) {
        case TxnType.debit:
          spent += txn.amountPaise;
        case TxnType.credit:
          got += txn.amountPaise;
      }
    }
    final totals = [
      if (spent > 0) '−${formatPaise(spent)}',
      if (got > 0) '+${formatPaise(got)}',
    ].join('   ');

    return Row(
      children: [
        Text(dayLabel(day), style: AppText.h3),
        const SizedBox(width: 12),
        // The totals shrink before the day's name gets squeezed.
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(totals, style: AppText.small),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.month, required this.filter});

  final DateTime month;
  final _Filter filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PennyMascot(size: 100),
            const SizedBox(height: 16),
            Text(
              'Nothing in ${monthLabel(month)}',
              style: AppText.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              filter == _Filter.all
                  ? 'Entries you add show up here.'
                  : 'No ${filter.label.toLowerCase()} entries this month.',
              style: AppText.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
