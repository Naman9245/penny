import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/add_txn/add_txn_controller.dart';
import 'package:penny/features/add_txn/amount_keypad.dart';
import 'package:penny/features/add_txn/category_grid.dart';
import 'package:penny/features/import/sms_card.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/insight_math.dart';
import 'package:penny/services/sms_parser.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/edge_fade.dart';
import 'package:penny/widgets/sliding_toggle.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Adds an entry, or edits one when [editId] is set: type the amount, pick a
/// category, tap ✓.
class AddTxnScreen extends ConsumerWidget {
  const AddTxnScreen({
    super.key,
    this.initialType = TxnType.debit,
    this.editId,
  });

  final TxnType initialType;
  final String? editId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = editId;
    if (id == null) return AddTxnView(args: AddTxnArgs.create(initialType));
    return ref
        .watch(txnByIdProvider(id))
        .when(
          data: (txn) => txn == null
              ? const _Gone()
              : AddTxnView(args: AddTxnArgs.edit(txn)),
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
    with TickerProviderStateMixin {
  static const _types = <ToggleOption<TxnType>>[
    ToggleOption(value: TxnType.debit, label: 'Spent', color: AppColors.pink),
    ToggleOption(value: TxnType.credit, label: 'Got', color: AppColors.mint),
  ];

  late final _shakeAmount = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final _shakeCategories = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  bool _busy = false;

  AddTxnController get _controller =>
      ref.read(addTxnControllerProvider(widget.args).notifier);

  bool get _editing => widget.args.isEditing;

  bool get _importing => widget.args.sms != null;

  @override
  void dispose() {
    _shakeAmount.dispose();
    _shakeCategories.dispose();
    super.dispose();
  }

  /// Shakes whatever ✓ is still waiting for.
  void _nudge(AnimationController shake) {
    HapticFeedback.heavyImpact();
    shake.forward(from: 0);
  }

  void _pick(Category category) {
    HapticFeedback.selectionClick();
    _controller.selectCategory(category.id);
  }

  Future<void> _save() async {
    final state = ref.read(addTxnControllerProvider(widget.args));
    if (state.amountPaise <= 0) {
      _nudge(_shakeAmount);
      return;
    }
    final categoryId = state.categoryId;
    if (categoryId == null) {
      _nudge(_shakeCategories);
      return;
    }
    if (_busy) return;
    _busy = true;
    try {
      final repo = ref.read(txnRepositoryProvider);
      final id = await _controller.save();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (_editing) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Saved')));
      } else {
        showUndoSnackBar(
          context,
          message:
              'Added ${formatPaise(state.amountPaise)} · '
              '${categoryById(categoryId).label}',
          onUndo: () => repo.softDelete(id),
        );
      }
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

  /// Reads a copied bank SMS and swaps this screen for its review.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Copy a bank SMS first, then tap Paste SMS.'),
          ),
        );
      return;
    }
    context.pushReplacement('/import', extra: parseSms(text));
  }

  /// Walks through the steps: amount, then category, then ✓.
  String _prompt(AddTxnState state) {
    if (_editing) return 'Edit this entry';
    final spent = state.type == TxnType.debit;
    if (state.amountPaise <= 0) {
      return spent ? 'How much did you spend?' : 'How much did you get?';
    }
    if (state.categoryId == null) {
      return spent ? 'What was it for?' : 'Where did it come from?';
    }
    return _importing
        ? 'Check what Penny read, then tap the tick'
        : 'Tap the tick to save';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addTxnControllerProvider(widget.args));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Everything but the keypad scrolls together, header included,
            // so nothing ever slides underneath a pinned bar.
            Expanded(
              child: EdgeFade(
                size: 16,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          BrutalIconButton(
                            icon: Icons.close_rounded,
                            semanticLabel: 'Close',
                            onPressed: () => context.pop(),
                          ),
                          Expanded(
                            child: Center(
                              child: SlidingToggle<TxnType>(
                                options: _types,
                                value: state.type,
                                onChanged: _controller.setType,
                              ),
                            ),
                          ),
                          if (_editing)
                            BrutalIconButton(
                              icon: Icons.delete_outline_rounded,
                              semanticLabel: 'Delete',
                              color: AppColors.pink,
                              onPressed: _delete,
                            )
                          else
                            // Balances the close button so the toggle sits
                            // centred.
                            const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (widget.args.sms case final sms?) ...[
                        SmsCard(preview: sms.preview),
                        const SizedBox(height: 18),
                      ],
                      Text(_prompt(state), style: AppText.bodyMuted),
                      const SizedBox(height: 2),
                      _AmountDisplay(
                        text: state.amountText,
                        shake: _shakeAmount,
                      ),
                      const SizedBox(height: 14),
                      _DayAndWhere(
                        state: state,
                        onDay: _controller.setDay,
                        onPickDay: () => _pickDay(state.occurredAt),
                        onWhere: () => _editWhere(state.merchant),
                        onPaste: _editing || _importing ? null : _paste,
                        // A person read from the SMS, until the name is changed.
                        payeeIsPerson:
                            (widget.args.sms?.payeeIsPerson ?? false) &&
                            state.merchant == widget.args.sms?.payee,
                      ),
                      if (widget.args.editing case final txn?
                          when state.type == TxnType.debit) ...[
                        const SizedBox(height: 16),
                        _TagChoice(
                          tag: state.tag,
                          penny: PennyTags(
                            ref
                                .watch(
                                  insightProvider(monthStart(txn.occurredAt)),
                                )
                                .value,
                          ).of(txn),
                          onChanged: _controller.setTag,
                        ),
                      ],
                      const SizedBox(height: 24),
                      CategoryGrid(
                            categories: categoriesFor(state.type),
                            selectedId: state.categoryId,
                            onTap: _pick,
                          )
                          .animate(
                            controller: _shakeCategories,
                            autoPlay: false,
                          )
                          .shakeX(hz: 5, amount: 6),
                    ],
                  ),
                ),
              ),
            ),
            AmountKeypad(
              onKey: _controller.press,
              onBackspace: _controller.backspace,
              onClear: _controller.clear,
              onDone: _save,
              ready: state.canSave,
            ),
          ],
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
    this.onPaste,
    this.payeeIsPerson = false,
  });

  final AddTxnState state;
  final ValueChanged<DateTime> onDay;
  final VoidCallback onPickDay;
  final VoidCallback onWhere;

  /// Offered only for a new, hand-typed entry.
  final VoidCallback? onPaste;

  /// Shows a person, not a shop, on the payee chip.
  final bool payeeIsPerson;

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
          icon: payeeIsPerson ? Icons.person_rounded : Icons.storefront_rounded,
          selected: merchant != null,
          selectedColor: AppColors.sky,
          onTap: onWhere,
        ),
        if (onPaste case final paste?)
          BrutalChip(
            key: const ValueKey('paste-sms'),
            label: 'Paste SMS',
            icon: Icons.content_paste_rounded,
            onTap: paste,
          ),
      ],
    );
  }
}

/// Necessary or wasteful, for a spend being edited: Penny's pick until the
/// user makes their own.
class _TagChoice extends StatelessWidget {
  const _TagChoice({
    required this.tag,
    required this.penny,
    required this.onChanged,
  });

  /// The user's own pick.
  final TxnTag? tag;

  /// Penny's pick, from the month's report.
  final TxnTag? penny;
  final ValueChanged<TxnTag?> onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = tag ?? penny;
    final caption = tag != null
        ? 'Your pick'
        : penny != null
        ? "Penny's pick"
        : 'Not sorted yet';
    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            BrutalChip(
              key: const ValueKey('tag-necessary'),
              label: 'Necessary',
              selected: shown == TxnTag.necessary,
              selectedColor: AppColors.mint,
              onTap: () => onChanged(TxnTag.necessary),
            ),
            BrutalChip(
              key: const ValueKey('tag-wasteful'),
              label: 'Wasteful',
              selected: shown == TxnTag.wasteful,
              selectedColor: AppColors.pink,
              onTap: () => onChanged(TxnTag.wasteful),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(caption, style: AppText.small),
            if (tag != null) ...[
              const Text(' · ', style: AppText.small),
              Semantics(
                button: true,
                child: GestureDetector(
                  key: const ValueKey('tag-reset'),
                  onTap: () => onChanged(null),
                  child: Text(
                    penny != null ? "Use Penny's" : 'Clear',
                    style: AppText.small.copyWith(
                      color: AppColors.ink,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
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
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
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
                child: BrutalButton(
                  label: 'Done',
                  expand: true,
                  onPressed: _done,
                ),
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
