import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/money_kinds.dart';

/// A shop the user spent at lately, as My needs lists it.
@immutable
class ShopSeen {
  const ShopSeen({
    required this.key,
    required this.name,
    required this.totalPaise,
  });

  /// As [shopKey] writes it, which is how rules find it.
  final String key;

  /// The latest spelling the user saw.
  final String name;
  final int totalPaise;
}

/// The shops in [txns], biggest spend first. People the user paid aren't
/// shops, so they're left out.
List<ShopSeen> recentShops(Iterable<Txn> txns) {
  final totals = <String, int>{};
  final latest = <String, Txn>{};
  for (final txn in txns) {
    if (!txn.isSpend || isPersonPayee(txn)) continue;
    final key = shopKey(txn.merchant);
    if (key == null) continue;
    totals[key] = (totals[key] ?? 0) + txn.amountPaise;
    final seen = latest[key];
    if (seen == null || txn.occurredAt.isAfter(seen.occurredAt)) {
      latest[key] = txn;
    }
  }
  final shops = [
    for (final MapEntry(:key, value: total) in totals.entries)
      ShopSeen(
        key: key,
        name: latest[key]!.merchant!.trim(),
        totalPaise: total,
      ),
  ];
  shops.sort((a, b) => b.totalPaise.compareTo(a.totalPaise));
  return shops;
}

/// Shops from this month and the two before it.
final recentShopsProvider = StreamProvider.autoDispose<List<ShopSeen>>((ref) {
  final month = monthStart(DateTime.now());
  return ref
      .watch(txnRepositoryProvider)
      .watchBetween(DateTime(month.year, month.month - 2), nextMonth(month))
      .map(recentShops);
});
