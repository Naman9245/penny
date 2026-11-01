import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/widgets/brutal_card.dart';

/// Shows exactly what a tap on Ask Penny would send for [request]'s month.
Future<void> showSentSheet(BuildContext context, InsightRequest request) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _SentSheet(request: request),
  );
}

class _SentSheet extends StatelessWidget {
  const _SentSheet({required this.request});

  final InsightRequest request;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('What Penny sends', style: AppText.h2),
          const SizedBox(height: 4),
          const Text(
            "This month as totals per shop. People's names stay on your "
            'phone.',
            style: AppText.bodyMuted,
          ),
          const SizedBox(height: 16),
          if (request.spends.isNotEmpty) ...[
            const Text('Spends', style: AppText.label),
            const SizedBox(height: 8),
            _Rows(
              rows: [
                for (final spend in request.spends)
                  (
                    key: 'sent-${spend['id']}',
                    title: spend['name'] as String? ?? 'No shop name',
                    detail: _detail(
                      spend['category']! as String,
                      spend['entries']! as int,
                    ),
                    rupees: spend['total']! as int,
                  ),
              ],
            ),
          ],
          if (request.income.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Income', style: AppText.label),
            const SizedBox(height: 8),
            _Rows(
              rows: [
                for (final income in request.income)
                  (
                    key: 'sent-${income['id']}',
                    title: categoryById(income['category']! as String).label,
                    detail:
                        Steadiness.fromWire(income['steadiness'])?.label ?? '',
                    rupees: income['total']! as int,
                  ),
              ],
            ),
          ],
          if (request.body['note'] case final String note) ...[
            const SizedBox(height: 16),
            const Text('Your note', style: AppText.label),
            const SizedBox(height: 8),
            BrutalCard(
              padding: const EdgeInsets.all(14),
              child: Text(note, style: AppText.body),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Never sent: your SMS, account numbers, single entries, or who '
            'paid you.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }

  static String _detail(String categoryId, int entries) =>
      '${categoryById(categoryId).label} · '
      '${entries == 1 ? '1 entry' : '$entries entries'}';
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<({String key, String title, String detail, int rupees})> rows;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      padding: EdgeInsets.zero,
      clipChild: true,
      child: Column(
        children: [
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) const RowDivider(),
            Padding(
              key: ValueKey(row.key),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.title, style: AppText.bodyStrong),
                        if (row.detail.isNotEmpty)
                          Text(row.detail, style: AppText.small),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(formatPaise(row.rupees * 100), style: AppText.label),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
