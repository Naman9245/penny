import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/add_txn/add_txn_controller.dart';
import 'package:penny/features/add_txn/amount_keypad.dart';
import 'package:penny/features/add_txn/category_grid.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Adds an entry, or edits one when [editId] is set.
///
/// Adding is built for speed: type the amount, tap a category, done.
class AddTxnScreen extends ConsumerWidget {
  const AddTxnScreen({super.key, this.initialType = TxnType.debit, this.editId});

  final TxnType initialType;
  final String? editId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = editId;
    if (id == null) return AddTxnView(args: AddTxnArgs.create(initialType));
    return ref.watch(txnByIdProvider(id)).when(
          data: (txn) =>
              txn == null ? const _Gone() : AddTxnView(args: AddTxnArgs.edit(txn)),
          loading: () => const Scaffold(body: SizedBox.shrink()),
          error: (error, stackTrace) => const _Gone(),
        );
  }
}

class AddTxnView extends ConsumerStatefulWidget {
  const AddTxnView({super.key, required this.args});

  final AddTxnArgs args;

  @override
  ConsumerState<AddTxnView> createState() => _AddTxnViewState();
}

class _AddTxnViewState extends ConsumerState<AddTxnView>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _busy = false;

  AddTxnController get _controller =>
      ref.read(addTxnControllerProvider(widget.args).notifier);

  bool get _editing => widget.args.isEditing;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Shakes the amount: there's nothing to save yet.
  void _nudge() {
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
  }

  Future<void> _onCategory(Category category) async {
    if (_editing) {
      _controller.selectCategory(category.id);
      return;
    }
    final amount = ref.read(addTxnControllerProvider(widget.args)).amountPaise;
    if (amount <= 0) {
      _nudge();
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      final repo = ref.read(txnRepositoryProvider);
      final id = await _controller.saveNew(category.id);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      showUndoSnackBar(
        context,
        message: 'Added ${formatPaise(amount)} · ${category.label}',
        onUndo: () => repo.softDelete(id),
      );
      context.pop();
    } finally {
      _busy = false;
    }
  }

  Future<void> _saveEdit() async {
    if (ref.read(addTxnControllerProvider(widget.args)).amountPaise <= 0) {
      _nudge();
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      await _controller.saveEdit();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Saved')));
      context.pop();
    } finally {
      _busy = false;
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    _busy = true;
    try {
      final repo = ref.read(txnRepositoryProvider);
      final id = widget.args.editing!.id;
      await repo.softDelete(id);
      if (!mounted) return;
      showUndoSnackBar(
        context,
        message: 'Deleted',
        onUndo: () => repo.restore(id),
      );
      context.pop();
    } finally {
      _busy = false;
    }
  }

  Future<void> _pickDay(DateTime current) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(today) ? today : DateUtils.dateOnly(current),
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null && mounted) _controller.setDay(picked);
  }

  Future<void> _editWhere(String? current) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WhereSheet(initial: current),
    );
    if (result != null && mounted) _controller.setMerchant(result);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addTxnControllerProvider(widget.args));
    final prompt = _editing
        ? 'Edit this entry'
        : state.type == TxnType.debit
            ? 'How much did you spend?'
            : 'How much did you get?';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  BrutalIconButton(
                    icon: Icons.close_rounded,
                    semanticLabel: 'Close',
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: _TypeToggle(
                        type: state.type,
                        onChanged: _controller.setType,
                      ),
                    ),
                  ),
                  // Balances the close button so the toggle sits centred.
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                child: Column(
                  children: [
                    Text(prompt, style: AppText.bodyMuted),
                    const SizedBox(height: 2),
                    _AmountDisplay(text: state.amountText, shake: _shake),
                    const SizedBox(height: 14),
                    _DayAndWhere(
                      state: state,
                      onDay: _controller.setDay,
                      onPickDay: () => _pickDay(state.occurredAt),
                      onWhere: () => _editWhere(state.merchant),
                    ),
                    const SizedBox(height: 24),
                    CategoryGrid(
                      categories: categoriesFor(state.type),
                      selectedId: _editing ? state.categoryId : null,
                      onTap: _onCategory,
                    ),
                  ],
                ),
              ),
            ),
            AmountKeypad(
              onKey: _controller.press,
              onBackspace: _controller.backspace,
              onClear: _controller.clear,
            ),
            if (_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: BrutalButton(
                        label: 'Delete',
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.pink,
                        expand: true,
                        onPressed: _delete,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BrutalButton(
                        label: 'Save',
                        icon: Icons.check_rounded,
                        expand: true,
                        onPressed: state.categoryId == null ? null : _saveEdit,
                      ),
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

class _TypeToggle extends StatelessWidget {
  const _TypeToggle({required this.type, required this.onChanged});

  final TxnType type;
  final ValueChanged<TxnType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: brutalDecoration(color: AppColors.white, radius: kPillRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('Spent', TxnType.debit, AppColors.pink),
          _segment('Got', TxnType.credit, AppColors.mint),
        ],
      ),
    );
  }

  Widget _segment(String label, TxnType value, Color color) {
    final selected = value == type;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.white,
            borderRadius: BorderRadius.circular(kPillRadius),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.white,
              width: 2,
            ),
          ),
          child: Text(label, style: AppText.label),
        ),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.text, required this.shake});

  final String text;
  final AnimationController shake;

  @override
  Widget build(BuildContext context) {
    final shown = formatAmountText(text);
    return Semantics(
      liveRegion: true,
      label: 'Amount $shown',
      excludeSemantics: true,
      child: SizedBox(
        height: 64,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            shown,
            style: AppText.hero.copyWith(
              color: text.isEmpty ? AppColors.inkMuted : AppColors.ink,
            ),
          ),
        ),
      ),
    ).animate(controller: shake, autoPlay: false).shakeX(hz: 5, amount: 10);
  }
}

class _DayAndWhere extends StatelessWidget {
  const _DayAndWhere({
    required this.state,
    required this.onDay,
    required this.onPickDay,
    required this.onWhere,
  });

  final AddTxnState state;
  final ValueChanged<DateTime> onDay;
  final VoidCallback onPickDay;
  final VoidCallback onWhere;

  @override
  Widget build(BuildContext context) {
    final today = dayStart(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final day = dayStart(state.occurredAt);
    final earlier = day != today && day != yesterday;
    final merchant = state.merchant;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 10,
      children: [
        BrutalChip(
          label: 'Today',
          selected: day == today,
          onTap: () => onDay(today),
        ),
        BrutalChip(
          label: 'Yesterday',
          selected: day == yesterday,
          onTap: () => onDay(yesterday),
        ),
        BrutalChip(
          label: earlier ? DateFormat('d MMM').format(day) : 'Pick date',
          icon: Icons.calendar_today_rounded,
          selected: earlier,
          onTap: onPickDay,
        ),
        BrutalChip(
          label: merchant ?? 'Where?',
          icon: Icons.storefront_rounded,
          selected: merchant != null,
          selectedColor: AppColors.sky,
          onTap: onWhere,
        ),
      ],
    );
  }
}

/// Asks where the money went. Pops with the text, '' to clear it, or null
/// when dismissed.
class _WhereSheet extends StatefulWidget {
  const _WhereSheet({this.initial});

  final String? initial;

  @override
  State<_WhereSheet> createState() => _WhereSheetState();
}

class _WhereSheetState extends State<_WhereSheet> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _done() => Navigator.pop(context, _text.text);

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AppColors.ink, width: 2.5),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Where, or what was it?', style: AppText.h2),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _done(),
            style: AppText.body,
            decoration: const InputDecoration(
              hintText: 'Canteen, Swiggy, Metro…',
              counterText: '',
              filled: true,
              fillColor: AppColors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.initial != null) ...[
                Expanded(
                  child: BrutalButton(
                    label: 'Clear',
                    color: AppColors.white,
                    expand: true,
                    onPressed: () => Navigator.pop(context, ''),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: BrutalButton(label: 'Done', expand: true, onPressed: _done),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Gone extends StatelessWidget {
  const _Gone();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BrutalIconButton(
                icon: Icons.arrow_back_rounded,
                semanticLabel: 'Back',
                onPressed: () => context.pop(),
              ),
              const SizedBox(height: 24),
              const Text('This entry is gone.', style: AppText.h2),
              const SizedBox(height: 6),
              const Text('It may have been deleted.', style: AppText.bodyMuted),
            ],
          ),
        ),
      ),
    );
  }
}
