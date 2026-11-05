import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import 'package:penny/widgets/category_avatar.dart';
import 'package:penny/widgets/pressable_area.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Payments read from notifications, waiting to be checked, newest first.
final waitingCapturesProvider =
    StreamProvider.autoDispose<List<PendingCapture>>(
      (ref) => ref.watch(captureRepositoryProvider).watchWaiting(),
    );

/// The most shown at once; the rest come up as these are done.
const _shown = 5;

/// "2 payments to check": what Penny read from notifications. Each adds in
/// one tap with the category Penny guessed, opens to change anything, or is
/// skipped. One that may already be logged says so, and Skip comes first.
class ToCheckCard extends ConsumerWidget {
  const ToCheckCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waiting = ref.watch(waitingCapturesProvider).value ?? const [];
    if (waiting.isEmpty) return const SizedBox.shrink();
    final more = waiting.length - _shown;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: BrutalCard(
        key: const ValueKey('to-check'),
        color: AppColors.sky,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              waiting.length == 1
                  ? '1 payment to check'
                  : '${waiting.length} payments to check',
              style: AppText.h3,
            ),
            const SizedBox(height: 2),
            const Text(
              'Read from your notifications. Add each, or skip it.',
              style: AppText.small,
            ),
            for (final (i, capture) in waiting.take(_shown).indexed) ...[
              const SizedBox(height: 12),
              _CaptureRow(index: i, capture: capture),
            ],
            if (more > 0) ...[
              const SizedBox(height: 10),
              Text(
                more == 1 ? '1 more after these' : '$more more after these',
                style: AppText.small,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaptureRow extends ConsumerWidget {
  const _CaptureRow({required this.index, required this.capture});

  final int index;
  final PendingCapture capture;

  static const _apps = {
    'sms': 'SMS',
    'gpay': 'GPay',
    'phonepe': 'PhonePe',
    'paytm': 'Paytm',
  };

  /// Opens it pre-filled, to change anything before ✓ adds it.
  void _open(BuildContext context) => context.push('/capture', extra: capture);

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final categoryId = capture.suggestedCategoryId;
    if (categoryId == null) return _open(context);
    final txns = ref.read(txnRepositoryProvider);
    final captures = ref.read(captureRepositoryProvider);
    final id = await txns.add(
      amountPaise: capture.amountPaise,
      type: capture.type,
      categoryId: categoryId,
      occurredAt: capture.occurredAt,
      merchant: capture.payee,
      source: TxnSource.sms,
      dedupeKey: capture.dedupeKey,
      payeeIsPerson: capture.payeeIsPerson,
    );
    await captures.remove(capture.dedupeKey);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message:
          'Added ${formatPaise(capture.amountPaise)} · '
          '${kindLabel(capture.type, categoryId)}',
      onUndo: () async {
        await txns.softDelete(id);
        await captures.putBack(capture);
      },
    );
  }

  Future<void> _skip(BuildContext context, WidgetRef ref) async {
    final captures = ref.read(captureRepositoryProvider);
    await captures.skip(capture.dedupeKey);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: 'Skipped ${formatPaise(capture.amountPaise)}',
      onUndo: () => captures.putBack(capture),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryId = capture.suggestedCategoryId;
    final category = categoryId == null ? null : categoryById(categoryId);
    final sign = capture.type == TxnType.debit ? '−' : '+';
    final lookalike = capture.lookalike;
    final when =
        '${dayLabel(capture.occurredAt)}, '
        '${DateFormat('h:mm a').format(capture.occurredAt)}';
    final add = BrutalChip(
      key: ValueKey('capture-add-$index'),
      label: lookalike != null ? 'Add anyway' : 'Add',
      icon: Icons.add_rounded,
      onTap: () => _add(context, ref),
    );
    final skip = BrutalChip(
      key: ValueKey('capture-skip-$index'),
      label: 'Skip',
      icon: Icons.close_rounded,
      onTap: () => _skip(context, ref),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PressableArea(
          key: ValueKey('capture-$index'),
          radius: 12,
          onTap: () => _open(context),
          child: Row(
            children: [
              CategoryAvatar(category: category ?? spendCategories.last),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sign${formatPaise(capture.amountPaise)} · '
                      '${capture.payee ?? (capture.type == TxnType.debit ? 'Spent' : 'Got')}',
                      style: AppText.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (categoryId != null)
                          '${category!.emoji} ${kindLabel(capture.type, categoryId)}'
                        else
                          'Pick a category',
                        when,
                        _apps[capture.app] ?? capture.app,
                      ].join(' · '),
                      style: AppText.small,
                    ),
                    if (lookalike != null)
                      Text(
                        'Looks like $lookalike',
                        key: ValueKey('capture-lookalike-$index'),
                        style: AppText.small.copyWith(color: AppColors.ink),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // One that may already be logged offers Skip first.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: lookalike != null ? [skip, add] : [add, skip],
        ),
      ],
    );
  }
}
