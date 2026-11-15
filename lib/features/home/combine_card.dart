import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/combine_math.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/card_title.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Groups Penny was told "Not now" about, kept on this phone so she never
/// asks about them again.
final combineNotNowProvider = NotifierProvider<CombineNotNow, Set<String>>(
  CombineNotNow.new,
);

class CombineNotNow extends Notifier<Set<String>> {
  /// Where they're kept.
  static const key = 'combine_not_now';

  /// The most kept: an offer is only made for the last week anyway.
  static const _most = 60;

  @override
  Set<String> build() => {
    ...?ref.watch(sharedPrefsProvider).getStringList(key),
  };

  Future<void> add(String group) async {
    final kept = [...state.where((g) => g != group), group];
    final next = kept.length > _most ? kept.sublist(kept.length - _most) : kept;
    await ref.read(sharedPrefsProvider).setStringList(key, next);
    state = {...next};
  }
}

final _lastWeekProvider = StreamProvider.autoDispose<List<Txn>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(txnRepositoryProvider)
      .watchBetween(
        today.subtract(combineLookBack),
        today.add(const Duration(days: 1)),
      );
});

/// Payees with several payments on one day of the last week, which Penny
/// offers to make one.
final combineOffersProvider = Provider.autoDispose<List<CombineOffer>>(
  (ref) => combineOffers(
    ref.watch(_lastWeekProvider).value ?? const [],
    ref.watch(todayProvider),
    ref.watch(combineNotNowProvider),
  ),
);

/// Penny's offer on Home to make one payee's payments on one day one
/// entry, like two payments to a friend for the same lunch. One at a time;
/// nothing shows when there's none.
class CombineCard extends ConsumerWidget {
  const CombineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(combineOffersProvider);
    if (offers.isEmpty) return const SizedBox.shrink();
    final offer = offers.first;
    final count = offer.txns.length;

    Future<void> combine() async {
      final repo = ref.read(txnRepositoryProvider);
      final ids = [for (final txn in offer.txns) txn.id];
      final combined = await repo.combine(ids);
      if (combined == null || !context.mounted) return;
      showUndoSnackBar(
        context,
        message:
            'Combined $count into ${formatPaise(offer.totalPaise)} · '
            '${offer.payee}',
        onUndo: () => repo.uncombine(combined, ids),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: BrutalCard(
        key: const ValueKey('combine-offer'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle(
              icon: Icons.merge_rounded,
              color: AppColors.mint,
              title: 'Make these one?',
              subtitle:
                  '$count payments to ${offer.payee} · '
                  '${dayLabel(offer.day)} · ${formatPaise(offer.totalPaise)}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BrutalChip(
                  key: const ValueKey('combine-offer-yes'),
                  label: 'Combine',
                  icon: Icons.merge_rounded,
                  onTap: combine,
                ),
                BrutalChip(
                  key: const ValueKey('combine-offer-no'),
                  label: 'Not now',
                  onTap: () =>
                      ref.read(combineNotNowProvider.notifier).add(offer.key),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
