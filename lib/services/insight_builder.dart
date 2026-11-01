import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/sms_parser.dart';

// What Penny sends for a look at one month: month totals per shop, people
// only as "Person 1, 2…", income by category only. Never a single entry, an
// SMS or a person's name. The server checks all of this again.

/// Months a request reads: the month itself and the five before it.
const insightHistoryMonths = 6;

/// Penny needs a few spends before there is anything to look at.
const minSpendsToAsk = 3;

// Shop groups beyond this merge into their category's group. With at most 11
// categories that keeps a request within the server's 40 groups.
const _maxShopGroups = 28;

/// The first day a request for [month] reads from.
DateTime insightHistoryStart(DateTime month) {
  final start = monthStart(month);
  return DateTime(start.year, start.month - (insightHistoryMonths - 1));
}

/// Which group an entry belongs to: one shop in one category, or the
/// category alone when there's no shop name. Stays on the phone.
String groupKeyOf(Txn txn) {
  final shop = txn.merchant?.trim().toLowerCase().replaceAll(
    RegExp(r'\s+'),
    ' ',
  );
  return shop == null || shop.isEmpty
      ? 'cat|${txn.categoryId}'
      : 'shop|${txn.categoryId}|$shop';
}

/// Whether [txn]'s payee may reach the AI only as an alias. What the SMS
/// showed wins; otherwise any name that reads like a person's counts as one.
bool isPersonPayee(Txn txn) {
  if (txn.payeeIsPerson case final known?) return known;
  final merchant = txn.merchant;
  return merchant != null && looksLikePersonName(merchant);
}

/// A shop name with only letters and simple punctuation, so phone and
/// reference numbers can't ride along. Null when nothing is left.
String? cleanShopName(String? raw) {
  if (raw == null) return null;
  final name = raw
      .replaceAll(RegExp(r"[^\p{L}\p{M} &.'-]", unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final short = name.length > 32 ? name.substring(0, 32).trim() : name;
  return short.isEmpty ? null : short;
}

/// Everything about one request for Penny's look at a month.
@immutable
class InsightRequest {
  const InsightRequest({
    required this.month,
    required this.body,
    required this.groupKeys,
    required this.inputHash,
    required this.spendCount,
  });

  final DateTime month;

  /// Exactly what goes to the server.
  final Map<String, Object?> body;

  /// The local groups behind each id in [body]. Never sent.
  final Map<String, List<String>> groupKeys;

  /// Fingerprint of the money data in [body]. The user's own tags and the
  /// day of the month are left out, so neither makes a report look stale.
  final String inputHash;

  /// Spends in the month.
  final int spendCount;

  bool get canAsk => spendCount >= minSpendsToAsk;

  List<Map<String, Object?>> get spends =>
      (body['spends']! as List).cast<Map<String, Object?>>();

  List<Map<String, Object?>> get income =>
      (body['income']! as List).cast<Map<String, Object?>>();
}

/// The request for [month], from [txns]: entries from [insightHistoryStart]
/// to the end of the month. [now] says how far into the month it is.
InsightRequest buildInsightRequest({
  required DateTime month,
  required List<Txn> txns,
  required DateTime now,
}) {
  final start = monthStart(month);
  // 0 is [month], -1 the month before, and so on.
  int indexOf(DateTime at) =>
      (at.year - start.year) * 12 + at.month - start.month;

  final groups = <String, _Group>{};
  final incomes = <String, _Group>{};
  final lastMonthByKey = <String, int>{};
  final seenByKey = <String, Set<int>>{};
  final incomeMonths = <String, Set<int>>{};
  final activeMonths = <int>{};
  var spent = 0, got = 0, lastSpent = 0, lastGot = 0;

  for (final txn in txns) {
    final i = indexOf(txn.occurredAt);
    if (i > 0 || i <= -insightHistoryMonths) continue;
    activeMonths.add(i);
    final key = groupKeyOf(txn);
    switch ((txn.type, i)) {
      case (TxnType.debit, 0):
        spent += txn.amountPaise;
        (groups[key] ??= _Group(txn.categoryId)..keys.add(key)).add(txn);
      case (TxnType.credit, 0):
        got += txn.amountPaise;
        (incomes[txn.categoryId] ??= _Group(
          txn.categoryId,
        )..keys.add('income|${txn.categoryId}')).add(txn);
      case (TxnType.debit, _):
        if (i == -1) {
          lastSpent += txn.amountPaise;
          lastMonthByKey[key] = (lastMonthByKey[key] ?? 0) + txn.amountPaise;
        }
        if (i >= -3) (seenByKey[key] ??= {}).add(i);
      case (TxnType.credit, _):
        if (i == -1) lastGot += txn.amountPaise;
    }
    if (txn.type == TxnType.credit) {
      (incomeMonths[txn.categoryId] ??= {}).add(i);
    }
  }

  // The biggest shops keep their own group; the rest join their category's.
  final shops = groups.values.where((g) => g.isShop).toList()..sort(_byTotal);
  for (final shop in shops.skip(_maxShopGroups)) {
    final key = 'cat|${shop.categoryId}';
    groups.remove(shop.keys.single);
    (groups[key] ??= _Group(shop.categoryId)..keys.add(key)).absorb(shop);
  }
  final spendGroups = groups.values.toList()..sort(_byTotal);
  final incomeGroups = incomes.values.toList()..sort(_byTotal);

  final groupKeys = <String, List<String>>{};
  final spends = <Map<String, Object?>>[];
  var people = 0;
  for (final (n, group) in spendGroups.indexed) {
    final id = 's${n + 1}';
    groupKeys[id] = group.keys.toList()..sort();
    final person = group.isShop && group.txns.any(isPersonPayee);
    final lastMonth = group.keys.fold(
      0,
      (sum, key) => sum + (lastMonthByKey[key] ?? 0),
    );
    spends.add({
      'id': id,
      'name': person
          ? 'Person ${++people}'
          : group.isShop
          ? cleanShopName(group.latest.merchant)
          : null,
      'person': person,
      'category': group.categoryId,
      'entries': group.txns.length,
      'total': _rupees(group.totalPaise),
      'biggest': _rupees(group.biggestPaise),
      'lastMonth': _rupees(lastMonth),
      'monthsSeen': {for (final key in group.keys) ...?seenByKey[key]}.length,
      'yourTag': group.sharedTag?.name,
    });
  }

  final tracked = activeMonths.length;
  final income = <Map<String, Object?>>[];
  for (final (n, group) in incomeGroups.indexed) {
    final id = 'i${n + 1}';
    groupKeys[id] = group.keys.toList();
    final months = incomeMonths[group.categoryId]?.length ?? 0;
    income.add({
      'id': id,
      'category': group.categoryId,
      'entries': group.txns.length,
      'total': _rupees(group.totalPaise),
      'monthsWithIncome': months,
      'monthsTracked': tracked,
      'steadiness': steadinessOf(months, tracked).wire,
    });
  }

  final end = nextMonth(start);
  final complete = !now.isBefore(end);
  final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
  final body = <String, Object?>{
    'v': 1,
    'month': monthKey(start),
    'monthComplete': complete,
    'daysCounted': complete
        ? daysInMonth
        : now.isBefore(start)
        ? 1
        : now.day,
    'spent': _rupees(spent),
    'got': _rupees(got),
    'lastMonth': {'spent': _rupees(lastSpent), 'got': _rupees(lastGot)},
    'spends': spends,
    'income': income,
  };

  return InsightRequest(
    month: start,
    body: body,
    groupKeys: groupKeys,
    inputHash: _fingerprint(body),
    spendCount: groups.values.fold(0, (sum, g) => sum + g.txns.length),
  );
}

/// How steady a source with income in [months] of the [tracked] months
/// Penny has data for has been.
Steadiness steadinessOf(int months, int tracked) {
  if (tracked < 3) return Steadiness.tooEarly;
  if (months >= tracked) return Steadiness.steady;
  if (months * 3 >= tracked * 2) return Steadiness.mostMonths;
  return Steadiness.nowAndThen;
}

String _fingerprint(Map<String, Object?> body) {
  final money = {
    for (final MapEntry(:key, :value) in body.entries)
      if (key != 'monthComplete' && key != 'daysCounted') key: value,
    'spends': [
      for (final spend in body['spends']! as List)
        {
          for (final MapEntry(:key, :value) in (spend as Map).entries)
            if (key != 'yourTag') key: value,
        },
    ],
  };
  return sha256
      .convert(utf8.encode('penny-insight-v1|${jsonEncode(money)}'))
      .toString();
}

int _rupees(int paise) => (paise / 100).round();

int _byTotal(_Group a, _Group b) {
  final byTotal = b.totalPaise.compareTo(a.totalPaise);
  return byTotal != 0 ? byTotal : a.keys.first.compareTo(b.keys.first);
}

class _Group {
  _Group(this.categoryId);

  final String categoryId;
  final keys = <String>{};
  final txns = <Txn>[];
  var totalPaise = 0;
  var biggestPaise = 0;

  bool get isShop => keys.length == 1 && keys.single.startsWith('shop|');

  Txn get latest =>
      txns.reduce((a, b) => b.occurredAt.isAfter(a.occurredAt) ? b : a);

  /// The user's own tag, when every entry has the same one.
  TxnTag? get sharedTag {
    final tags = txns.map((t) => t.tag).toSet();
    return tags.length == 1 ? tags.single : null;
  }

  void add(Txn txn) {
    txns.add(txn);
    totalPaise += txn.amountPaise;
    if (txn.amountPaise > biggestPaise) biggestPaise = txn.amountPaise;
  }

  void absorb(_Group other) {
    keys.addAll(other.keys);
    other.txns.forEach(add);
  }
}
