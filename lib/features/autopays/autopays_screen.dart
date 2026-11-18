import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/autopay_math.dart';
import 'package:penny/widgets/amount_sheet.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/card_title.dart';
import 'package:penny/widgets/category_avatar.dart';
import 'package:penny/widgets/page_header.dart';
import 'package:penny/widgets/pressable_area.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Every autopay: the ones that still go out, soonest first, with what they
/// come to a month, then the paused and cancelled ones. Penny finds them in
/// messages; + adds one by hand.
class AutopaysScreen extends ConsumerWidget {
  const AutopaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autopays = ref.watch(autopaysProvider).value ?? const <Autopay>[];
    final today = ref.watch(todayProvider);
    final going = [...autopays.where(isActive)]
      ..sort((a, b) {
        final ad = dueOn(a, today);
        final bd = dueOn(b, today);
        if (ad == null || bd == null) return ad == null ? 1 : -1;
        return ad.compareTo(bd);
      });
    final stopped = [
      for (final autopay in autopays)
        if (!isActive(autopay)) autopay,
    ];
    final monthly = monthlyPaise(autopays);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            PageHeader(
              title: 'Autopays',
              subtitle: monthly > 0
                  ? '${formatPaise(wholeRupees(monthly))} a month goes out '
                        'by itself'
                  : 'Payments that go out by themselves.',
              actions: [
                BrutalIconButton(
                  key: const ValueKey('autopay-add'),
                  icon: Icons.add_rounded,
                  semanticLabel: 'Add an autopay',
                  color: AppColors.yellow,
                  onPressed: () => showAutopaySheet(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const BrutalCard(
              color: AppColors.lavender,
              child: CardTitle(
                icon: Icons.notifications_active_rounded,
                color: AppColors.yellow,
                title: 'Penny reminds you',
                subtitle:
                    '5 days and 1 day before each one goes out, around '
                    '10 AM. She finds them in your messages too.',
              ),
            ),
            const SizedBox(height: 20),
            if (autopays.isEmpty)
              const Text(
                'No autopays yet. When a message sets one up or takes one, '
                'Penny adds it here. Or tap + to add one.',
                style: AppText.body,
              )
            else ...[
              if (going.isNotEmpty) _List(autopays: going, today: today),
              if (stopped.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Paused or cancelled', style: AppText.h3),
                const SizedBox(height: 8),
                _List(autopays: stopped, today: today),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.autopays, required this.today});

  final List<Autopay> autopays;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      padding: EdgeInsets.zero,
      clipChild: true,
      child: Column(
        children: [
          for (final (i, autopay) in autopays.indexed) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.hairline),
            PressableArea(
              key: ValueKey('autopay-${autopay.id}'),
              onTap: () => showAutopaySheet(context, editing: autopay),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    CategoryAvatar(
                      category: categoryById(
                        autopay.categoryId ?? 'subscriptions',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            autopay.name,
                            style: AppText.bodyStrong,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            autopayLine(autopay, today),
                            style: AppText.small,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.ink,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Adds an autopay, or changes [editing]: who it's to, how much, how often
/// and the next day it goes out; one can be paused or deleted.
Future<void> showAutopaySheet(BuildContext context, {Autopay? editing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AutopaySheet(editing: editing),
    );

class _AutopaySheet extends ConsumerStatefulWidget {
  const _AutopaySheet({required this.editing});

  final Autopay? editing;

  @override
  ConsumerState<_AutopaySheet> createState() => _AutopaySheetState();
}

class _AutopaySheetState extends ConsumerState<_AutopaySheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late int _amountPaise = widget.editing?.amountPaise ?? 0;
  late AutopayEvery _every = widget.editing?.every ?? AutopayEvery.monthly;
  late DateTime? _nextOn = widget.editing?.nextOn;
  late bool _paused = widget.editing?.paused ?? false;

  static const _everyLabels = {
    AutopayEvery.weekly: 'Week',
    AutopayEvery.monthly: 'Month',
    AutopayEvery.quarterly: '3 months',
    AutopayEvery.yearly: 'Year',
  };

  bool get _canSave => _name.text.trim().isNotEmpty && _amountPaise > 0;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAmount() async {
    final paise = await showAmountSheet(
      context,
      title: 'How much goes out?',
      initialPaise: _amountPaise > 0 ? _amountPaise : null,
    );
    if (paise != null && mounted) setState(() => _amountPaise = paise);
  }

  Future<void> _pickDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextOn != null && !_nextOn!.isBefore(today)
          ? _nextOn!
          : today,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _nextOn = picked);
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final repo = ref.read(autopayRepositoryProvider);
    final editing = widget.editing;
    if (editing == null) {
      await repo.add(
        name: _name.text,
        amountPaise: _amountPaise,
        every: _every,
        nextOn: _nextOn,
      );
    } else {
      await repo.edit(
        editing.id,
        name: _name.text,
        amountPaise: _amountPaise,
        every: _every,
        nextOn: Value(_nextOn),
        paused: _paused,
        // Saving a cancelled one starts it again.
        endedAt: const Value(null),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final editing = widget.editing!;
    final repo = ref.read(autopayRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    await repo.delete(editing.id);
    if (!mounted) return;
    Navigator.pop(context);
    showUndoSnackBarOn(
      messenger,
      message: 'Deleted ${editing.name}',
      onUndo: () => repo.restore(editing.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing == null ? 'New autopay' : editing.name,
                style: AppText.h2,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('autopay-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Who it goes to',
                  hintText: 'Spotify, rent, a SIP…',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              BrutalChip(
                key: const ValueKey('autopay-amount'),
                label: _amountPaise > 0
                    ? formatPaise(_amountPaise)
                    : 'How much?',
                icon: Icons.currency_rupee_rounded,
                selected: _amountPaise > 0,
                onTap: _pickAmount,
              ),
              const SizedBox(height: 16),
              const Text('How often', style: AppText.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final every in AutopayEvery.values)
                    BrutalChip(
                      key: ValueKey('autopay-every-${every.name}'),
                      label: _everyLabels[every]!,
                      selected: _every == every,
                      onTap: () => setState(() => _every = every),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Next goes out', style: AppText.label),
              const SizedBox(height: 8),
              BrutalChip(
                key: const ValueKey('autopay-day'),
                label: _nextOn == null
                    ? 'Pick a day'
                    : DateFormat('EEE, d MMM').format(_nextOn!),
                icon: Icons.calendar_today_rounded,
                selected: _nextOn != null,
                onTap: _pickDay,
              ),
              if (editing != null) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  key: const ValueKey('autopay-paused'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Paused', style: AppText.bodyStrong),
                  subtitle: const Text(
                    'No reminders while it is.',
                    style: AppText.small,
                  ),
                  value: _paused,
                  onChanged: (on) => setState(() => _paused = on),
                ),
              ],
              const SizedBox(height: 18),
              BrutalButton(
                key: const ValueKey('autopay-save'),
                label: editing == null ? 'Add autopay' : 'Save',
                expand: true,
                color: _canSave ? AppColors.yellow : AppColors.sand,
                onPressed: _canSave ? _save : null,
              ),
              if (editing != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    key: const ValueKey('autopay-delete'),
                    onPressed: _delete,
                    child: const Text(
                      'Delete this autopay',
                      style: AppText.label,
                    ),
                  ),
                ),
              ],
              if (editing?.endedAt case final ended?) ...[
                const SizedBox(height: 8),
                Text(
                  'Cancelled ${dayLabel(ended).toLowerCase()}. Saving it '
                  'again starts it again.',
                  style: AppText.small,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
