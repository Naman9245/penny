import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/money_kinds.dart';

/// What combining some entries makes: one entry for their total.
typedef Combined = ({
  int amountPaise,
  TxnType type,
  String categoryId,
  DateTime occurredAt,
  String? merchant,
  bool? payeeIsPerson,
  TxnSource source,
});

/// What combining [txns] makes: their total, on the latest one's day and
/// time, with the payee and category they share, or else the first one's.
/// Null for fewer than two, or when they aren't all the same kind of money
/// (spent, got, paid back or invested), which can't add up to one.
Combined? combinationOf(List<Txn> txns) {
  if (txns.length < 2) return null;
  final kind = txns.first.kind;
  if (txns.any((txn) => txn.kind != kind)) return null;
  final byTime = [...txns]
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final first = byTime.first;
  return (
    amountPaise: txns.fold(0, (sum, txn) => sum + txn.amountPaise),
    type: first.type,
    categoryId: first.categoryId,
    occurredAt: byTime.last.occurredAt,
    merchant: first.merchant,
    payeeIsPerson: first.payeeIsPerson,
    source: first.source,
  );
}

/// Several payments to one payee on one day, which Penny offers to make
/// one.
typedef CombineOffer = ({
  String key,
  String payee,
  DateTime day,
  List<Txn> txns,
  int totalPaise,
});

/// How far back Penny looks for payments to offer to combine.
const combineLookBack = Duration(days: 7);

/// The offers Penny makes on [today]: each payee with two or more payments
/// out on one day of the last week, newest day first, but not those in
/// [notNow].
List<CombineOffer> combineOffers(
  Iterable<Txn> txns,
  DateTime today,
  Set<String> notNow,
) {
  final from = dayStart(today).subtract(combineLookBack);
  final groups = <String, List<Txn>>{};
  for (final txn in txns) {
    if (!txn.isSpend || txn.occurredAt.isBefore(from)) continue;
    final shop = shopKey(txn.merchant);
    if (shop == null) continue;
    final day = dayStart(txn.occurredAt);
    final key = '${monthKey(day)}-${day.day}|$shop';
    (groups[key] ??= []).add(txn);
  }
  final offers = [
    for (final MapEntry(:key, value: group) in groups.entries)
      if (group.length >= 2 && !notNow.contains(key))
        (
          key: key,
          payee: group.first.merchant!,
          day: dayStart(group.first.occurredAt),
          txns: group,
          totalPaise: group.fold(0, (sum, txn) => sum + txn.amountPaise),
        ),
  ];
  return offers..sort((a, b) => b.day.compareTo(a.day));
}
