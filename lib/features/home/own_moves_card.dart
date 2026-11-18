import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/own_moves.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/card_title.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Moves the user chose to keep as two entries, kept on this phone so
/// Penny never asks about them again.
final ownMovesKeptProvider = NotifierProvider<OwnMovesKept, Set<String>>(
  OwnMovesKept.new,
);

class OwnMovesKept extends Notifier<Set<String>> {
  /// Where they're kept.
  static const key = 'own_moves_kept';

  /// The most kept: Penny only looks back three months anyway.
  static const _most = 60;

  @override
  Set<String> build() => {
    ...?ref.watch(sharedPrefsProvider).getStringList(key),
  };

  Future<void> add(String move) async {
    final kept = [...state.where((m) => m != move), move];
    final next = kept.length > _most ? kept.sublist(kept.length - _most) : kept;
    await ref.read(sharedPrefsProvider).setStringList(key, next);
    state = {...next};
  }
}

/// The entries of the last three months, watched so the offer follows
/// every change.
final _recentProvider = StreamProvider.autoDispose<List<Txn>>((ref) {
  final today = ref.watch(todayProvider);
  return ref
      .watch(txnRepositoryProvider)
      .watchBetween(
        today.subtract(pastMovesLookBack),
        today.add(const Duration(days: 1)),
      );
});

/// Moves between the user's own accounts that were saved as two entries,
/// money out and money in, before Penny knew to pair them.
final pastMovesProvider = FutureProvider.autoDispose<List<PastMove>>((
  ref,
) async {
  ref.watch(_recentProvider);
  final kept = ref.watch(ownMovesKeptProvider);
  final moves = await pastMovesOf(
    ref.watch(appDatabaseProvider),
    ref.watch(todayProvider).subtract(pastMovesLookBack),
  );
  return [
    for (final move in moves)
      if (!kept.contains(move.key)) move,
  ];
});

/// Penny's offer on Home to take out a move between your own accounts,
/// like PayZapp to the bank, that was saved as −₹2,000 and +₹2,000. One at
/// a time; nothing shows when there's none.
class OwnMovesCard extends ConsumerWidget {
  const OwnMovesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moves = ref.watch(pastMovesProvider).value ?? const [];
    if (moves.isEmpty) return const SizedBox.shrink();
    final move = moves.first;
    final amount = formatPaise(move.amountPaise);
    final way = move.toBank
        ? 'from your wallet to your bank'
        : 'from your bank into your wallet';
    final day = dayLabel(move.at);
    final when = day == 'Today' || day == 'Yesterday'
        ? day.toLowerCase()
        : 'on $day';

    Future<void> remove() async {
      final db = ref.read(appDatabaseProvider);
      final repo = ref.read(txnRepositoryProvider);
      await removePastMove(db, repo, move, now: DateTime.now());
      if (!context.mounted) return;
      showUndoSnackBar(
        context,
        message: 'Took out both. $amount was your own money moving',
        onUndo: () => putBackMove(db, repo, [move.walletEntry, move.bankEntry]),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: BrutalCard(
        key: const ValueKey('own-move-offer'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CardTitle(
              icon: Icons.swap_horiz_rounded,
              color: AppColors.sky,
              title: 'Your own money moving?',
              subtitle:
                  '$amount went $way $when. '
                  "Penny saved it as −$amount and +$amount, but it isn't "
                  'money in or out.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                BrutalChip(
                  key: const ValueKey('own-move-remove'),
                  label: 'Take out both',
                  icon: Icons.swap_horiz_rounded,
                  onTap: remove,
                ),
                BrutalChip(
                  key: const ValueKey('own-move-keep'),
                  label: 'Keep them',
                  onTap: () =>
                      ref.read(ownMovesKeptProvider.notifier).add(move.key),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
