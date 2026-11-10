import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/category.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/money_text.dart';

/// Payments messages said are coming, like an autopay or an EMI, soonest
/// first, so none is a surprise. Nothing shows when none is coming.
class ComingUpCard extends ConsumerWidget {
  const ComingUpCard({super.key});

  /// Rows shown at most; the rest come up as these go.
  static const _most = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(comingUpProvider);
    if (due.isEmpty) return const SizedBox.shrink();
    final today = ref.watch(todayProvider);
    final card = BrutalCard(
      key: const ValueKey('coming-up'),
      color: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.event_rounded, size: 20, color: AppColors.ink),
              SizedBox(width: 8),
              Text('Coming up', style: AppText.h3),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Payments your messages say are on their way.',
            style: AppText.small,
          ),
          for (final (i, payment) in due.take(_most).indexed) ...[
            const SizedBox(height: 10),
            _Row(
              index: i,
              payment: payment,
              today: today,
              onDismiss: () => ref
                  .read(upcomingRepositoryProvider)
                  .dismiss(payment.dedupeKey),
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
    required this.payment,
    required this.today,
    required this.onDismiss,
  });

  final int index;
  final UpcomingPayment payment;
  final DateTime today;
  final VoidCallback onDismiss;

  String get _when {
    final days = payment.dueOn.difference(today).inDays;
    final date = DateFormat('d MMM').format(payment.dueOn);
    return switch (days) {
      < 0 => 'Was due $date',
      0 => 'Today',
      1 => 'Tomorrow',
      _ => date,
    };
  }

  String get _name {
    if (payment.payee case final payee? when payee.trim().isNotEmpty) {
      return payee;
    }
    if (payment.categoryId case final id?) return categoryById(id).label;
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
        MoneyText(payment.amountPaise, style: AppText.bodyStrong),
        IconButton(
          key: ValueKey('coming-up-dismiss-$index'),
          tooltip: 'Not coming',
          icon: const Icon(Icons.close_rounded, size: 20),
          color: AppColors.ink,
          onPressed: onDismiss,
        ),
      ],
    );
  }
}
