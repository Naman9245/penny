import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/flat_section.dart';

/// Shows exactly what asking Penny would send for [request]'s month, with
/// [goal] as a plan sends it, or [goals] as the chat sends them.
Future<void> showSentSheet(
  BuildContext context,
  InsightRequest request, {
  Map<String, Object?>? goal,
  List<ChatGoal> goals = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        _SentSheet(request: request, goal: goal, goals: goals),
  );
}

class _SentSheet extends StatelessWidget {
  const _SentSheet({
    required this.request,
    required this.goal,
    required this.goals,
  });

  final InsightRequest request;
  final Map<String, Object?>? goal;
  final List<ChatGoal> goals;

  @override
  Widget build(BuildContext context) {
    final budget = request.body['budget'] as Map<String, Object?>?;
    final goal = this.goal;
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
          Text(
            "${DateFormat('MMMM').format(request.month)} as totals per shop, "
            'and the months before as totals. '
            "People's names stay on your phone.",
            style: AppText.bodyMuted,
          ),
          if (goal != null) ...[
            const SizedBox(height: 16),
            const Text('Your goal', style: AppText.label),
            const SizedBox(height: 8),
            _Rows(
              rows: [
                (
                  key: 'sent-goal',
                  title: goal['title']! as String,
                  detail: 'Target',
                  rupees: goal['target']! as int,
                ),
                (
                  key: 'sent-goal-saved',
                  title: 'Put aside so far',
                  detail: '',
                  rupees: goal['saved']! as int,
                ),
                (
                  key: 'sent-goal-week',
                  title: 'Still needed a week',
                  detail: '${goal['weeksLeft']} weeks left',
                  rupees: goal['perWeek']! as int,
                ),
                (
                  key: 'sent-goal-month',
                  title: 'Still needed a month',
                  detail: '',
                  rupees: goal['perMonth']! as int,
                ),
              ],
            ),
          ],
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
          if (goals.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Your goals', style: AppText.label),
            const SizedBox(height: 8),
            _Rows(
              rows: [
                for (final (i, goal) in goals.indexed)
                  (
                    key: 'sent-goals-$i',
                    title: maskLongNumbers(goal.title),
                    detail:
                        '${formatPaise(goal.savedPaise)} put aside · by '
                        '${DateFormat('d MMM y').format(goal.deadline)}',
                    rupees: (goal.targetPaise / 100).round(),
                  ),
              ],
            ),
          ],
          if (budget != null) ...[
            const SizedBox(height: 16),
            const Text('Your budget', style: AppText.label),
            const SizedBox(height: 8),
            _Rows(
              rows: [
                if (budget['everyday'] case final int everyday)
                  (
                    key: 'sent-budget',
                    title: 'Everyday budget',
                    detail: 'A month',
                    rupees: everyday,
                  ),
                for (final cap in budget['caps']! as List)
                  if (cap case {
                    'category': final String id,
                    'cap': final int rupees,
                  })
                    (
                      key: 'sent-cap-$id',
                      title: '${categoryById(id).label} budget',
                      detail: 'A month',
                      rupees: rupees,
                    ),
              ],
            ),
          ],
          if (request.body['history'] case final List history
              when history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Your months before', style: AppText.label),
            const SizedBox(height: 8),
            _Rows(
              rows: [
                for (final month in history.reversed)
                  if (month case {
                    'month': final String key,
                    'spent': final int spent,
                    'categories': final List categories,
                  })
                    (
                      key: 'sent-history-$key',
                      title: DateFormat('MMMM yyyy')
                          .format(DateTime.parse('$key-01')),
                      detail:
                          'Spent, got, invested, and '
                          '${categories.length == 1 ? '1 category' : '${categories.length} categories'}',
                      rupees: spent,
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
    return FlatSection(
      padding: EdgeInsets.zero,
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
