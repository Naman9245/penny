import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/month_summary.dart';
import 'package:penny/models/penny_mood.dart';

/// One database for the app's lifetime. Tests override it with an
/// in-memory one.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final txnRepositoryProvider = Provider<TxnRepository>(
  (ref) => TxnRepository(ref.watch(appDatabaseProvider)),
);

/// Entries in the month containing the given date, newest first.
final monthTxnsProvider = StreamProvider.autoDispose
    .family<List<Txn>, DateTime>(
      (ref, month) => ref.watch(txnRepositoryProvider).watchMonth(month),
    );

final monthSummaryProvider = StreamProvider.autoDispose
    .family<MonthSummary, DateTime>(
      (ref, month) => ref.watch(txnRepositoryProvider).watchMonthSummary(month),
    );

final recentTxnsProvider = StreamProvider.autoDispose<List<Txn>>(
  (ref) => ref.watch(txnRepositoryProvider).watchRecent(),
);

final txnByIdProvider = FutureProvider.autoDispose.family<Txn?, String>(
  (ref, id) => ref.watch(txnRepositoryProvider).findById(id),
);

/// The live entry an SMS with this fingerprint was already imported as.
final txnByDedupeKeyProvider = FutureProvider.autoDispose.family<Txn?, String>(
  (ref, key) => ref.watch(txnRepositoryProvider).findByDedupeKey(key),
);

/// Penny's current mood. Neutral until budgets arrive in Milestone 4; then
/// it comes from spending pace against the caps.
final pennyMoodProvider = Provider<PennyMood>((ref) => PennyMood.neutral);
