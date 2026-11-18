import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/category.dart';
import 'package:penny/services/upcoming_math.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/card_title.dart';
import 'package:penny/widgets/money_text.dart';

/// Payments coming, soonest first, so none is a surprise: ones messages
/// said are on their way, like an EMI, and autopays' next days. Nothing
/// shows when none is coming.
class ComingUpCard extends ConsumerWidget {
  const ComingUpCard({super.key});

  /// Rows shown at most; the rest come up as these go.
  static const _most = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueSoonProvider);
    if (due.isEmpty) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final card = BrutalCard(
      key: const ValueKey('coming-up'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardTitle(
            icon: Icons.event_rounded,
            color: AppColors.lavender,
            title: 'Coming up',
            subtitle:
                'Payments on their way. Penny reminds you before '
                'autopays.',
            trailing: TextButton(
              key: const ValueKey('coming-up-autopays'),
              onPressed: () => context.push('/autopays'),
              child: const Text('Autopays', style: AppText.label),
            ),
          ),
          for (final (i, item) in due.take(_most).indexed) ...[
            SizedBox(height: i == 0 ? 8 : 2),
            _Row(
              index: i,
              item: item,
              today: today,
              onDismiss: item.autopayId == null
                  ? () => ref.read(upcomingRepositoryProvider).dismiss(item.key)
                  : null,
              onOpen: item.autopayId == null
                  ? null
                  : () => context.push('/autopays'),
            ),
          ],
        ],
      ),
    );
    return Padding(padding: const EdgeInsets.only(top: 16), child: card);
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.index,
    required this.item,
    required this.today,
    required this.onDismiss,
    required this.onOpen,
  });

  final int index;
  final DueItem item;
  final DateTime today;

  /// Takes a payment a message said is coming off the card.
  final VoidCallback? onDismiss;

  /// Opens the autopays, for an autopay's row.
  final VoidCallback? onOpen;

  String get _when {
    final days = item.dueOn.difference(today).inDays;
    final date = DateFormat('d MMM').format(item.dueOn);
    final day = switch (days) {
      < 0 => 'Was due $date',
      0 => 'Today',
      1 => 'Tomorrow',
      _ => date,
    };
    return item.autopayId == null ? day : '$day · Autopay';
  }

  String get _name {
    if (item.name case final name? when name.trim().isNotEmpty) return name;
    if (item.categoryId case final id?) return categoryById(id).label;
    return 'A payment';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: ValueKey('coming-up-$index'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name,
                style: AppText.bodyStrong,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(_when, style: AppText.small.copyWith(color: AppColors.ink)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        MoneyText(item.amountPaise, style: AppText.bodyStrong),
        if (onDismiss case final dismiss?)
          IconButton(
            key: ValueKey('coming-up-dismiss-$index'),
            tooltip: 'Not coming',
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.ink,
            onPressed: dismiss,
          )
        else
          IconButton(
            key: ValueKey('coming-up-open-$index'),
            tooltip: 'Autopays',
            icon: const Icon(Icons.autorenew_rounded, size: 20),
            color: AppColors.ink,
            onPressed: onOpen,
          ),
      ],
    );
  }
}
