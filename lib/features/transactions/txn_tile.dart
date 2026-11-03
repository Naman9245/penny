import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/widgets/category_avatar.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/pressable_area.dart';

/// One transaction row: category face, what it was, when, and the signed
/// amount.
class TxnTile extends StatelessWidget {
  const TxnTile({
    super.key,
    required this.txn,
    this.onTap,
    this.showDay = false,
  });

  final Txn txn;
  final VoidCallback? onTap;

  /// Show the day instead of the time, for lists not grouped by day.
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    final category = categoryById(txn.categoryId);
    final merchant = txn.merchant;
    final when = showDay
        ? dayLabel(txn.occurredAt)
        : DateFormat('h:mm a').format(txn.occurredAt);
    final subtitle = [
      if (merchant != null) category.label,
      when,
      if (txn.source != TxnSource.manual) 'SMS',
    ].join(' · ');

    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: PressableArea(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  CategoryAvatar(category: category),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          merchant ?? category.label,
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
