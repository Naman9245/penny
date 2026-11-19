import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/transactions/txn_tile.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/penny_pose.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/combine_math.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/txn_search.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/month_switcher.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/undo_snack_bar.dart';
import 'package:penny/widgets/page_header.dart';

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
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Opens the search box, or closes it and clears the search.
  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) {
      _search.clear();
      _query = '';
    }
  });

  // Rows swiped away but still in the database stream. Dismissible needs
  // them out of the tree on the very next frame.
  final _dismissed = <String>{};

  /// Entries picked to combine, after a long press. Empty when not picking.
  final _picked = <String>{};

  bool get _picking => _picked.isNotEmpty;

  void _togglePick(Txn txn) => setState(() {
    if (!_picked.remove(txn.id)) _picked.add(txn.id);
  });

  /// Makes the picked entries one, with Undo.
  Future<void> _combine(List<Txn> picked) async {
    final repo = ref.read(txnRepositoryProvider);
    final ids = [for (final txn in picked) txn.id];
    final total = picked.fold(0, (sum, txn) => sum + txn.amountPaise);
    final combined = await repo.combine(ids);
    if (!mounted || combined == null) return;
    setState(_picked.clear);
    showUndoSnackBar(
      context,
      message: 'Combined ${ids.length} into ${formatPaise(total)}',
      onUndo: () => repo.uncombine(combined, ids),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txns = ref.watch(monthTxnsProvider(_month));
    final categoryId = _categoryId;
    final picked = [
      for (final txn in txns.value ?? const <Txn>[])
        if (_picked.contains(txn.id)) txn,
    ];

    return PopScope(
      // Back while picking stops picking.
      canPop: !_picking,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_picked.clear);
      },
      child: Scaffold(
        bottomNavigationBar: _picking
            ? _CombineBar(
                picked: picked,
                onCombine: () => _combine(picked),
                onCancel: () => setState(_picked.clear),
              )
            : null,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: PageHeader(
                  title: 'Transactions',
                  subtitle: _picking
                      ? 'Tap the others to combine with it.'
                      : 'Tap to edit, hold to combine, swipe left to delete.',
                  actions: [
                    BrutalIconButton(
                      key: const ValueKey('search-toggle'),
                      icon: _searching
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      semanticLabel: _searching ? 'Close search' : 'Search',
                      onPressed: _toggleSearch,
                    ),
                  ],
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _SearchField(
                    controller: _search,
                    onChanged: (text) => setState(() => _query = text),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: MonthSwitcher(
                  month: _month,
                  onChanged: (month) => setState(() {
                    _month = month;
                    _picked.clear();
                  }),
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
                      )
                    else if (txns.value?.isNotEmpty ?? false)
                      BrutalChip(
                        key: const ValueKey('category-pick'),
                        label: 'Category',
                        icon: Icons.tune_rounded,
                        onTap: () => _pickCategory(txns.value!),
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
      ),
    );
  }

  /// Lets the user pick one of the categories [month]'s entries are in.
  Future<void> _pickCategory(List<Txn> month) async {
    final present = {for (final txn in month) txn.categoryId};
    final choices = [
      for (final category in allCategories)
        if (present.contains(category.id)) category,
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Show one category', style: AppText.h2),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in choices)
                    BrutalChip(
                      key: ValueKey('pick-category-${category.id}'),
                      label: category.label,
                      icon: category.icon,
                      onTap: () => Navigator.pop(context, category.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _categoryId = picked);
  }

  Widget _days(List<Txn> all) {
    final visible = [
      for (final txn in all)
        if (!_dismissed.contains(txn.id) &&
            _filter.keeps(txn) &&
            (_categoryId == null || txn.categoryId == _categoryId) &&
            matchesSearch(txn, _query))
          txn,
    ];
    final query = _query.trim();
    if (visible.isEmpty) {
      return _EmptyMonth(month: _month, filter: _filter, query: query);
    }
    // Anything narrowed down gets added up.
    final narrowed =
        _filter != _Filter.all || _categoryId != null || query.isNotEmpty;

    final byDay = <DateTime, List<Txn>>{};
    for (final txn in visible) {
      byDay.putIfAbsent(dayStart(txn.occurredAt), () => []).add(txn);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (narrowed) ...[
          Text(
            totalLine(visible),
            key: const ValueKey('filter-total'),
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: 12),
        ],
        for (final MapEntry(key: day, value: txns) in byDay.entries) ...[
          _DayHeader(day: day, txns: txns),
          const SizedBox(height: 4),
          // Flat rows between hairlines, as on Home.
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppColors.hairline),
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < txns.length; i++) ...[
                  if (i > 0) const RowDivider(),
                  if (_picking)
                    TxnTile(
                      key: ValueKey('pick-${txns[i].id}'),
                      txn: txns[i],
                      picked: _picked.contains(txns[i].id),
                      onTap: () => _togglePick(txns[i]),
                      onLongPress: () => _togglePick(txns[i]),
                    )
                  else
                    _Swipeable(
                      txn: txns[i],
                      onDelete: _delete,
                      onLongPress: _togglePick,
                    ),
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
          '${kindLabel(txn.type, txn.categoryId)}',
      onUndo: () {
        repo.restore(txn.id);
        if (mounted) setState(() => _dismissed.remove(txn.id));
      },
    );
  }
}

class _Swipeable extends StatelessWidget {
  const _Swipeable({
    required this.txn,
    required this.onDelete,
    required this.onLongPress,
  });

  final Txn txn;
  final ValueChanged<Txn> onDelete;
  final ValueChanged<Txn> onLongPress;

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
      child: TxnTile(
        txn: txn,
        onTap: () => context.push('/txns/${txn.id}'),
        onLongPress: () => onLongPress(txn),
      ),
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
  const _EmptyMonth({
    required this.month,
    required this.filter,
    this.query = '',
  });

  final DateTime month;
  final _Filter filter;

  /// What was searched for, if anything.
  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PennyMascot(pose: PennyPose.sleepy, size: 100),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'Nothing matches "$query"'
                  : 'Nothing in ${monthLabel(month)}',
              style: AppText.h3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              query.isNotEmpty
                  ? 'Try a place, a category or an amount, or another '
                        'month.'
                  : filter == _Filter.all
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

/// The search box: a place, a category or an amount.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AppColors.ink, width: kBorderWidth),
    );
    return TextField(
      key: const ValueKey('txn-search'),
      controller: controller,
      autofocus: true,
      maxLength: 40,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      style: AppText.body,
      decoration: const InputDecoration(
        hintText: 'Swiggy, food or 250',
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.ink),
        counterText: '',
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: border,
        enabledBorder: border,
        focusedBorder: border,
      ),
    );
  }
}

/// The bar while entries are picked: what combining them makes, or why it
/// can't yet, and a way out.
class _CombineBar extends StatelessWidget {
  const _CombineBar({
    required this.picked,
    required this.onCombine,
    required this.onCancel,
  });

  final List<Txn> picked;
  final VoidCallback onCombine;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final combined = combinationOf(picked);
    final label = switch (picked.length) {
      < 2 => 'Pick one more to combine',
      final n when combined != null =>
        'Combine $n · ${formatPaise(combined.amountPaise)}',
      _ => 'Pick only money out, or only money in',
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: BrutalButton(
                key: const ValueKey('combine'),
                label: label,
                icon: Icons.merge_rounded,
                expand: true,
                onPressed: combined == null ? null : onCombine,
              ),
            ),
            const SizedBox(width: 10),
            BrutalIconButton(
              key: const ValueKey('combine-cancel'),
              icon: Icons.close_rounded,
              semanticLabel: 'Stop picking',
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}
