import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/widgets/category_avatar.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/pressable_area.dart';

/// One transaction row: category face, what it was, when, and the signed
/// amount. A combined entry says how many it was made of: "2 in 1".
class TxnTile extends ConsumerWidget {
  const TxnTile({
    super.key,
    required this.txn,
    this.onTap,
    this.onLongPress,
    this.picked,
    this.showDay = false,
  });

  final Txn txn;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// While entries are being picked: whether this one is. Null otherwise.
  final bool? picked;

  /// Show the day instead of the time, for lists not grouped by day.
  final bool showDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = categoryById(txn.categoryId);
    final parts = ref.watch(combinedCountsProvider).value?[txn.id] ?? 0;
    // "Food · paid back" for money that came back.
    final what = kindLabel(txn.type, txn.categoryId);
    final merchant = txn.merchant;
    final when = showDay
        ? dayLabel(txn.occurredAt)
        : DateFormat('h:mm a').format(txn.occurredAt);
    final subtitle = [
      if (merchant != null) what,
      when,
      ?switch (txn.source) {
        TxnSource.manual => null,
        TxnSource.share => 'SMS',
        // Read from a notification.
        TxnSource.sms => 'Auto',
      },
      if (parts > 0) '$parts in 1',
    ].join(' · ');

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        selected: picked,
        child: PressableArea(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  switch (picked) {
                    null => CategoryAvatar(category: category),
                    final on => _PickMark(picked: on),
                  },
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant ?? what,
                          style: AppText.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppText.small,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // A huge amount shrinks instead of squeezing out the title.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * 0.4,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: MoneyText(txn.amountPaise, type: txn.type),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round tick in the avatar's place while entries are being picked.
class _PickMark extends StatelessWidget {
  const _PickMark({required this.picked});

  final bool picked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: picked ? AppColors.yellow : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 2),
      ),
      child: picked
          ? const Icon(Icons.check_rounded, color: AppColors.ink)
          : null,
    );
  }
}
