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
import 'package:penny/widgets/amount_keypad.dart';
import 'package:penny/features/add_txn/category_grid.dart';
import 'package:penny/features/import/sms_card.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/insight_math.dart';
import 'package:penny/services/quick_add.dart';
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

  Future<void> _editWhere(AddTxnState state) async {
    final result = await showModalBottomSheet<_Where>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WhereSheet(
        type: state.type,
        initial: state.merchant,
        // Only while there's no amount yet, so a place like "Sector 18"
        // never changes one already typed.
        readsAmount: state.amountPaise <= 0,
        categoryId: state.categoryId,
      ),
    );
    if (result == null || !mounted) return;
    if (result.typed case final typed?) {
      _controller.useTyped(typed);
    } else {
      _controller.setMerchant(result.text);
    }
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
    // Offered only for something new, not over an entry or an SMS.
    final usual = _editing || _importing
        ? const <UsualEntry>[]
        : ref.watch(usualEntriesProvider(state.type)).value ?? const [];

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
                        split: state.split,
                        shake: _shakeAmount,
                      ),
                      const SizedBox(height: 14),
                      _DayAndWhere(
                        state: state,
                        onDay: _controller.setDay,
                        onPickDay: () => _pickDay(state.occurredAt),
                        onWhere: () => _editWhere(state),
                        onPaste: _editing || _importing ? null : _paste,
                        // A person read from the SMS, until the name is changed.
                        payeeIsPerson:
                            (widget.args.sms?.payeeIsPerson ?? false) &&
                            state.merchant == widget.args.sms?.payee,
                      ),
                      if (usual.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Again(
                          entries: usual,
                          state: state,
                          onTap: _controller.useUsual,
                        ),
                      ],
                      if (widget.args.editing case final txn?
                          when state.type == TxnType.debit) ...[
                        const SizedBox(height: 16),
                        _TagChoice(
                          tag: state.tag,
                          rule: ref.watch(yourRulesProvider).value?.of(txn),
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
            _SplitRow(shown: state.amountPaise > 0, onSplit: _controller.split),
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
  const _AmountDisplay({required this.text, required this.shake, this.split});

  final String text;
  final AnimationController shake;

  /// The bill this amount is a share of.
  final BillSplit? split;

  @override
  Widget build(BuildContext context) {
    final sum = isSum(text);
    final total = sumTextToPaise(text);
    final split = this.split;
    // A sum or a split shows how it was worked out small, with what it
    // comes to big.
    final shown = sum ? formatPaise(total) : formatAmountText(text);
    final working = sum
        ? formatSumText(text)
        : split == null
        ? null
        : '${formatPaise(split.totalPaise)} ÷ ${split.ways}';
    return Semantics(
      liveRegion: true,
      label: sum
          ? 'Amount $shown, from ${formatSumText(text)}'
          : split != null
          ? 'Amount $shown, ${formatPaise(split.totalPaise)} split '
                '${split.ways} ways'
          : 'Amount $shown',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            child: working == null
                ? null
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      working,
                      key: ValueKey(sum ? 'amount-sum' : 'split-note'),
                      style: AppText.bodyStrong,
                    ),
                  ),
          ),
          SizedBox(
            height: 64,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                shown,
                style: AppText.hero.copyWith(
                  color: total > 0 ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ),
        ],
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

/// The entries the user logs again and again, a tap from filled in. ✓ still
/// saves.
class _Again extends StatelessWidget {
  const _Again({
    required this.entries,
    required this.state,
    required this.onTap,
  });

  final List<UsualEntry> entries;
  final AddTxnState state;
  final ValueChanged<UsualEntry> onTap;

  bool _filledIn(UsualEntry entry) =>
      state.amountPaise == entry.amountPaise &&
      state.categoryId == entry.categoryId &&
      state.merchant == entry.place;

  @override
  Widget build(BuildContext context) {
    // One line that scrolls sideways, so the categories stay where they are.
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            const Text('Again?', style: AppText.small),
            for (final (i, entry) in entries.indexed) ...[
              const SizedBox(width: 8),
              BrutalChip(
                key: ValueKey('again-$i'),
                label: _label(entry),
                selected: _filledIn(entry),
                onTap: () => onTap(entry),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _label(UsualEntry entry) {
    final category = categoryById(entry.categoryId);
    return '${category.emoji} ${entry.place ?? category.label} · '
        '${formatPaise(entry.amountPaise)}';
  }
}

/// ÷2 ÷3 ÷4, for a bill shared with friends. Its place is kept while
/// there's no amount, so the screen doesn't move when one is typed.
class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.shown, required this.onSplit});

  final bool shown;
  final ValueChanged<int> onSplit;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 150),
      child: IgnorePointer(
        ignoring: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Split it', style: AppText.small),
                for (final ways in const [2, 3, 4]) ...[
                  const SizedBox(width: 8),
                  BrutalChip(
                    key: ValueKey('split-$ways'),
                    label: '÷$ways',
                    semanticLabel: 'Split $ways ways',
                    onTap: () => onSplit(ways),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Necessary or wasteful, for a spend being edited: Penny's pick until the
/// user makes their own.
class _TagChoice extends StatelessWidget {
  const _TagChoice({
    required this.tag,
    required this.rule,
    required this.penny,
    required this.onChanged,
  });

  /// The user's own pick for this entry.
  final TxnTag? tag;

  /// What My needs says for its shop or category.
  final TxnTag? rule;

  /// Penny's pick, from the month's report.
  final TxnTag? penny;
  final ValueChanged<TxnTag?> onChanged;

  @override
  Widget build(BuildContext context) {
    final shown = tag ?? rule ?? penny;
    final caption = tag != null
        ? 'Your pick'
        : rule != null
        ? 'Your rule'
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
                    rule != null
                        ? 'Use your rule'
                        : penny != null
                        ? "Use Penny's"
                        : 'Clear',
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

/// What the Where sheet gives back: the words as typed, '' to clear the
/// place, and the whole entry when an amount came with them.
typedef _Where = ({String text, TypedEntry? typed});

/// Asks where the money went. While there's no amount yet it also takes one
/// typed with the words, like "240 swiggy". Pops null when dismissed.
class _WhereSheet extends StatefulWidget {
  const _WhereSheet({
    required this.type,
    required this.readsAmount,
    this.initial,
    this.categoryId,
  });

  final TxnType type;

  /// Whether an amount among the words fills in the amount too.
  final bool readsAmount;
  final String? initial;

  /// The category already picked, which wins over one the words suggest.
  final String? categoryId;

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

  TypedEntry? get _typed =>
      widget.readsAmount ? readTypedEntry(_text.text, type: widget.type) : null;

  void _done() =>
      Navigator.pop<_Where>(context, (text: _text.text, typed: _typed));

  /// "₹240 · 🍔 Food · Swiggy": what Done will fill in.
  String _preview(TypedEntry typed) {
    final categoryId = widget.categoryId ?? typed.categoryId;
    final category = categoryId == null ? null : categoryById(categoryId);
    return [
      formatPaise(typed.amountPaise),
      if (category != null) '${category.emoji} ${category.label}',
      ?typed.place,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: AppColors.ink, width: 2.5),
    );
    final typed = _typed;
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
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _done(),
            style: AppText.body,
            decoration: InputDecoration(
              hintText: widget.readsAmount
                  ? 'Swiggy, Metro… or 240 swiggy'
                  : 'Canteen, Swiggy, Metro…',
              counterText: '',
              filled: true,
              fillColor: AppColors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: border,
              enabledBorder: border,
              focusedBorder: border,
            ),
          ),
          if (typed != null) ...[
            const SizedBox(height: 10),
            Text.rich(
              key: const ValueKey('quick-preview'),
              TextSpan(
                children: [
                  const TextSpan(text: 'Done fills in  ', style: AppText.small),
                  TextSpan(text: _preview(typed), style: AppText.bodyStrong),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.initial != null) ...[
                Expanded(
                  child: BrutalButton(
                    label: 'Clear',
                    color: AppColors.white,
                    expand: true,
                    onPressed: () =>
                        Navigator.pop<_Where>(context, (text: '', typed: null)),
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
