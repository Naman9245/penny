import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/features/transactions/txn_tile.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/flat_section.dart';

/// One day from the mood calendar: Penny's face for it, the numbers behind
/// the face, and the day's entries.
Future<void> showDaySheet(
  BuildContext context, {
  required DateTime date,
  required PennyMood? mood,
  required List<Txn> entries,
  required DaySpending spend,
  required int? sharePaise,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the whole app, nav bar too, so it can't stay open behind a tab.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => _DaySheet(
      date: date,
      mood: mood,
      entries: entries,
      spend: spend,
      sharePaise: sharePaise,
    ),
  );
}

class _DaySheet extends StatelessWidget {
  const _DaySheet({
    required this.date,
    required this.mood,
    required this.entries,
    required this.spend,
    required this.sharePaise,
  });

  final DateTime date;
  final PennyMood? mood;
  final List<Txn> entries;

  /// The day's spending as Penny counts it.
  final DaySpending spend;
  final int? sharePaise;

  @override
  Widget build(BuildContext context) {
    final share = sharePaise;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(DateFormat('EEEE, d MMMM').format(date), style: AppText.h2),
          const SizedBox(height: 12),
          Row(
            children: [
              PennyMascot(
                mood: mood ?? PennyMood.neutral,
                size: 64,
                bob: false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // With a budget, only what the face goes by is set
                    // against the share; the rest is listed apart.
                    Text(
                      share == null
                          ? '${formatTotal(spend.counted + spend.noBudget)} '
                                'spent'
                          : '${formatTotal(spend.counted)} of your '
                                '${formatTotal(share)} share',
                      key: const ValueKey('day-spent'),
                      style: AppText.bodyStrong,
                    ),
                    if (share != null && spend.noBudget > 0)
                      Text(
                        'Plus ${formatTotal(spend.noBudget)} with no budget',
                        style: AppText.small,
                      ),
                    if (spend.oneGo > 0)
                      Text(
                        'Plus ${formatTotal(spend.oneGo)} paid in one go',
                        style: AppText.small,
                      ),
                    if (spend.cameBack > 0)
                      Text(
                        '${formatTotal(spend.cameBack)} came back',
                        key: const ValueKey('day-came-back'),
                        style: AppText.small,
                      ),
                    if (spend.invested > 0)
                      Text(
                        '${formatTotal(spend.invested)} invested',
                        key: const ValueKey('day-invested'),
                        style: AppText.small,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Text('Nothing spent. Nice!', style: AppText.bodyMuted)
          else
            FlatSection(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, txn) in entries.indexed) ...[
                    if (i > 0) const RowDivider(),
                    TxnTile(
                      txn: txn,
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push('/txns/${txn.id}');
                      },
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
