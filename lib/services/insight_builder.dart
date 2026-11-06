import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/payee_names.dart';

// What Penny sends for a look at one month: month totals per shop, people
// only as "Person 1, 2…", income by category only, and the months before as
// totals. Never a single entry, an SMS or a person's name. The server checks
// all of this again.

/// Months the groups' trends and the income's steadiness go by: the month
/// itself and the five before it.
const insightHistoryMonths = 6;

/// Months a request reads: the month itself and the eleven before it, which
/// go as month totals.
const insightRequestMonths = 12;

/// Penny needs a few spends before there is anything to look at.
const minSpendsToAsk = 3;

// Shop groups beyond this merge into their category's group. With at most 11
// categories that keeps a request within the server's 40 groups.
const _maxShopGroups = 28;

/// The first day a request for [month] reads from.
DateTime insightHistoryStart(DateTime month) {
  final start = monthStart(month);
  return DateTime(start.year, start.month - (insightRequestMonths - 1));
}

/// Which group an entry belongs to: one shop in one category, or the
/// category alone when there's no shop name. Stays on the phone.
String groupKeyOf(Txn txn) {
  final shop = shopKey(txn.merchant);
  return shop == null
      ? 'cat|${txn.categoryId}'
      : 'shop|${txn.categoryId}|$shop';
}

/// Whether [txn]'s payee may reach the AI only as an alias. What the SMS
/// showed wins; otherwise a typed name with no word Penny knows counts as a
/// person's.
bool isPersonPayee(Txn txn) {
  if (txn.payeeIsPerson case final known?) return known;
  final merchant = txn.merchant;
  return merchant != null && safePayeeName(merchant) == null;
}

/// Nine or more digits in a row, spaces or dashes allowed between them:
/// phone, account and card numbers. Amounts written with commas, like
/// 1,20,000, don't count.
final _longNumber = RegExp(r'\d(?:[\s-]?\d){8,}');

/// [text] with every long number hidden as •••, before it leaves the
/// phone. The server does the same again, as it must not rely on this.
String maskLongNumbers(String text) => text.replaceAll(_longNumber, '•••');

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
/// to the end of the month. [now] says how far into the month it is. Groups
/// that [rules] or the user's own tags settle go with that tag fixed, and
/// [note] and [budget] go along when there are any.
InsightRequest buildInsightRequest({
  required DateTime month,
  required List<Txn> txns,
  required DateTime now,
  YourRules rules = YourRules.none,
  String? note,
  Budget budget = Budget.none,
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
  final thisMonthTxns = <Txn>[];
  final lastMonthTxns = <Txn>[];
  final earlierTxns = <int, List<Txn>>{};

  // Groups are spends and income only. What came back and what was put away
  // count in the month's totals.
  for (final txn in txns) {
    final i = indexOf(txn.occurredAt);
    if (i > 0 || i <= -insightRequestMonths) continue;
    if (i < 0) (earlierTxns[i] ??= []).add(txn);
    if (i <= -insightHistoryMonths) continue;
    activeMonths.add(i);
    if (i == 0) thisMonthTxns.add(txn);
    if (i == -1) lastMonthTxns.add(txn);
    final key = groupKeyOf(txn);
    switch ((txn.kind, i)) {
      case (MoneyKind.spent, 0):
        (groups[key] ??= _Group(txn.categoryId)..keys.add(key)).add(txn);
      case (MoneyKind.got, 0):
        (incomes[txn.categoryId] ??= _Group(
          txn.categoryId,
        )..keys.add('income|${txn.categoryId}')).add(txn);
      case (MoneyKind.spent, _):
        if (i == -1) {
          lastMonthByKey[key] = (lastMonthByKey[key] ?? 0) + txn.amountPaise;
        }
        if (i >= -3) (seenByKey[key] ??= {}).add(i);
      case (MoneyKind.got || MoneyKind.paidBack || MoneyKind.invested, _):
        break;
    }
    if (txn.kind == MoneyKind.got) {
      (incomeMonths[txn.categoryId] ??= {}).add(i);
    }
  }
  // Counted the way Home counts them, so the chat's numbers match it.
  final thisMonth = MoneyTotals.of(thisMonthTxns);
  final lastMonth = MoneyTotals.of(lastMonthTxns);

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
          ? cleanShopName(group.shopName)
          : null,
      'person': person,
      'category': group.categoryId,
      'entries': group.txns.length,
      'total': _rupees(group.totalPaise),
      'biggest': _rupees(group.biggestPaise),
      'lastMonth': _rupees(lastMonth),
      'monthsSeen': {for (final key in group.keys) ...?seenByKey[key]}.length,
      'yourTag': group.sharedTag(rules)?.name,
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

  // What came back and what was put away go as totals only, so whoever paid
  // back is never named. Sent only when there are any, so other months'
  // fingerprints stay as they were.
  final paidBack = [
    for (final category in spendCategories)
      if (thisMonth.paidBackIn(category.id) case final paise when paise > 0)
        {'category': category.id, 'total': _someRupees(paise)},
  ];

  // The months before, oldest first, as totals: what the month spent, got
  // and put away, and what each spend category spent.
  final history = [
    for (var i = 1 - insightRequestMonths; i < 0; i++)
      if (earlierTxns[i] case final monthTxns?)
        _historyMonth(
          DateTime(start.year, start.month + i),
          MoneyTotals.of(monthTxns),
        ),
  ];

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
    'spent': _rupees(thisMonth.spentPaise),
    'got': _rupees(thisMonth.gotPaise),
    'lastMonth': {
      'spent': _rupees(lastMonth.spentPaise),
      'got': _rupees(lastMonth.gotPaise),
    },
    'spends': spends,
    'income': income,
    if (note?.trim() case final text? when text.isNotEmpty)
      'note': maskLongNumbers(text),
    // Each category's amount goes as a cap, and the everyday part of their
    // total as the everyday budget.
    if (!budget.isEmpty)
      'budget': {
        'everyday': budget.everydayPaise > 0
            ? _someRupees(budget.everydayPaise)
            : null,
        'caps': [
          for (final category in spendCategories)
            if (budget.byCategory[category.id] case final amount?)
              {'category': category.id, 'cap': _someRupees(amount)},
        ],
      },
    if (paidBack.isNotEmpty) 'paidBack': paidBack,
    if (thisMonth.investedPaise > 0)
      'invested': _someRupees(thisMonth.investedPaise),
    if (history.isNotEmpty) 'history': history,
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

Map<String, Object?> _historyMonth(DateTime month, MoneyTotals totals) => {
  'month': monthKey(month),
  'spent': _rupees(totals.spentPaise),
  'got': _rupees(totals.gotPaise),
  'invested': _rupees(totals.investedPaise),
  'categories': [
    for (final category in spendCategories)
      if (totals.spentIn(category.id) case final paise when paise > 0)
        {'category': category.id, 'spent': _someRupees(paise)},
  ],
};

/// Whole rupees, at least one: a budget of a few paise is still a budget.
int _someRupees(int paise) => math.max(1, _rupees(paise));

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

  /// What Penny may call this shop: its whole name once an SMS showed it's a
  /// business, otherwise only the words of the typed name she knows.
  String? get shopName {
    final merchant = latest.merchant;
    if (merchant == null) return null;
    final fromSms = txns.any((txn) => txn.payeeIsPerson == false);
    return fromSms ? merchant : safePayeeName(merchant);
  }

  /// The user's call, from their own tags or [rules], when every entry gets
  /// the same one.
  TxnTag? sharedTag(YourRules rules) {
    final tags = txns.map((t) => t.tag ?? rules.of(t)).toSet();
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
