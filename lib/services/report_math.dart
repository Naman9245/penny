import 'dart:math' as math;

import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/money_kinds.dart';

// The Money report's numbers, all worked out on the phone from the entries
// as they are: where the money went, the months before, and when it goes.
// Penny's AI never makes any of them.

/// One spend category in a month: what it spent (with money back taken
/// off), its share of all spending, how many payments, and its biggest
/// shop.
typedef CategoryShare = ({
  String categoryId,
  int spentPaise,
  double share,
  int count,
  String? topShop,
});

/// A shop, or a person, and what was paid to them in a month.
typedef ShopTotal = ({
  String name,
  String categoryId,
  int paidPaise,
  int count,
  bool isPerson,
});

/// One of the biggest single payments.
typedef BigSpend = ({String name, String categoryId, int paise, DateTime at});

/// A month's money, as Home counts it.
typedef MonthLine = ({
  DateTime month,
  int spentPaise,
  int gotPaise,
  int leftPaise,
});

/// A category's spending this month against the month before.
typedef CategoryChange = ({String categoryId, int nowPaise, int beforePaise});

/// Parts of the day, as the patterns split them.
enum DayPart {
  morning('Morning', '5 AM–12 PM'),
  afternoon('Afternoon', '12–5 PM'),
  evening('Evening', '5–10 PM'),
  lateNight('Late night', '10 PM–5 AM');

  const DayPart(this.label, this.hours);

  final String label;
  final String hours;

  static DayPart of(DateTime at) => switch (at.hour) {
    >= 5 && < 12 => morning,
    >= 12 && < 17 => afternoon,
    >= 17 && < 22 => evening,
    _ => lateNight,
  };
}

/// When the month's money went: by day of the week (Monday first), by part
/// of the day, the average weekday and weekend day so far, and the small
/// payments (under ₹100) that add up.
typedef SpendPatterns = ({
  List<int> byWeekdayPaise,
  Map<DayPart, int> byPartPaise,
  int weekdayAveragePaise,
  int weekendAveragePaise,
  int smallCount,
  int smallPaise,
});

/// A payment under this is a small one.
const smallSpendPaise = 10000;

/// The Money report for [month], from [txns] (that month and any before it)
/// as of [now].
class MoneyReport {
  MoneyReport._({
    required this.totals,
    required this.categories,
    required this.shops,
    required this.biggest,
    required this.history,
    required this.changes,
    required this.newShops,
    required this.savedSoFarPaise,
    required this.patterns,
  });

  factory MoneyReport.of({
    required DateTime month,
    required List<Txn> txns,
    required DateTime now,
  }) {
    final start = monthStart(month);
    final end = nextMonth(start);
    final inMonth = [
      for (final txn in txns)
        if (!txn.occurredAt.isBefore(start) && txn.occurredAt.isBefore(end))
          txn,
    ];
    final spends = [
      for (final txn in inMonth)
        if (txn.isSpend) txn,
    ];
    final totals = MoneyTotals.of(inMonth);

    return MoneyReport._(
      totals: totals,
      categories: _categories(totals, spends),
      shops: _shops(spends),
      biggest: _biggest(spends),
      history: _history(start, txns),
      changes: _changes(start, txns, totals),
      newShops: _newShops(start, txns, spends),
      savedSoFarPaise: _history(start, txns).fold(
        0,
        (sum, line) => sum + line.leftPaise,
      ),
      patterns: _patterns(start, end, now, spends),
    );
  }

  /// The month's money, as Home counts it.
  final MoneyTotals totals;

  /// Spend categories, biggest first.
  final List<CategoryShare> categories;

  /// The 10 shops and people paid most, biggest first.
  final List<ShopTotal> shops;

  /// The 5 biggest single payments, biggest first.
  final List<BigSpend> biggest;

  /// Up to 12 months up to this one, oldest first, from the first month
  /// with anything in it.
  final List<MonthLine> history;

  /// Categories that changed against last month, biggest change first.
  /// Empty with no month before.
  final List<CategoryChange> changes;

  /// Shops paid this month for the first time, when there's a month before
  /// to compare with.
  final List<String> newShops;

  /// Every month's Left in [history], added up: money kept, or lost when
  /// below zero.
  final int savedSoFarPaise;

  final SpendPatterns patterns;
}

/// How many months the history goes back, this one included.
const historyMonths = 12;

String _nameOf(Txn txn) {
  final name = txn.merchant?.trim();
  return name == null || name.isEmpty
      ? categoryById(txn.categoryId).label
      : name;
}

List<CategoryShare> _categories(MoneyTotals totals, List<Txn> spends) {
  final all = totals.spentPaise;
  final counts = <String, int>{};
  final byShop = <String, Map<String, int>>{};
  for (final txn in spends) {
    counts[txn.categoryId] = (counts[txn.categoryId] ?? 0) + 1;
    final shops = byShop[txn.categoryId] ??= {};
    final name = _nameOf(txn);
    shops[name] = (shops[name] ?? 0) + txn.amountPaise;
  }
  final shares = [
    for (final id in totals.spendIds)
      if (totals.spentIn(id) > 0)
        (
          categoryId: id,
          spentPaise: totals.spentIn(id),
          share: all == 0 ? 0.0 : totals.spentIn(id) / all,
          count: counts[id] ?? 0,
          topShop: _top(byShop[id]),
        ),
  ];
  return shares..sort((a, b) => b.spentPaise.compareTo(a.spentPaise));
}

String? _top(Map<String, int>? totals) {
  if (totals == null || totals.isEmpty) return null;
  return totals.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

List<ShopTotal> _shops(List<Txn> spends) {
  final byKey = <String, ({Txn first, int paise, int count})>{};
  for (final txn in spends) {
    final key = shopKey(txn.merchant) ?? 'cat|${txn.categoryId}';
    final seen = byKey[key];
    byKey[key] = (
      first: seen?.first ?? txn,
      paise: (seen?.paise ?? 0) + txn.amountPaise,
      count: (seen?.count ?? 0) + 1,
    );
  }
  final shops = [
    for (final shop in byKey.values)
      (
        name: _nameOf(shop.first),
        categoryId: shop.first.categoryId,
        paidPaise: shop.paise,
        count: shop.count,
        isPerson: shop.first.payeeIsPerson ?? false,
      ),
  ]..sort((a, b) => b.paidPaise.compareTo(a.paidPaise));
  return shops.take(10).toList();
}

List<BigSpend> _biggest(List<Txn> spends) {
  final sorted = [...spends]
    ..sort((a, b) => b.amountPaise.compareTo(a.amountPaise));
  return [
    for (final txn in sorted.take(5))
      (
        name: _nameOf(txn),
        categoryId: txn.categoryId,
        paise: txn.amountPaise,
        at: txn.occurredAt,
      ),
  ];
}

List<MonthLine> _history(DateTime start, List<Txn> txns) {
  final first = txns.isEmpty
      ? start
      : monthStart(txns.map((t) => t.occurredAt).reduce(_earlier));
  final from = DateTime(start.year, start.month - (historyMonths - 1));
  var month = first.isBefore(from) ? from : first;
  final lines = <MonthLine>[];
  while (!month.isAfter(start)) {
    final end = nextMonth(month);
    final m = month;
    final totals = MoneyTotals.of([
      for (final txn in txns)
        if (!txn.occurredAt.isBefore(m) && txn.occurredAt.isBefore(end)) txn,
    ]);
    lines.add((
      month: month,
      spentPaise: totals.spentPaise,
      gotPaise: totals.gotPaise,
      leftPaise: totals.leftPaise,
    ));
    month = end;
  }
  return lines;
}

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

List<CategoryChange> _changes(
  DateTime start,
  List<Txn> txns,
  MoneyTotals now,
) {
  final before = DateTime(start.year, start.month - 1);
  final lastTxns = [
    for (final txn in txns)
      if (!txn.occurredAt.isBefore(before) && txn.occurredAt.isBefore(start))
        txn,
  ];
  if (lastTxns.isEmpty) return const [];
  final last = MoneyTotals.of(lastTxns);
  final ids = {...now.spendIds, ...last.spendIds};
  final changes = [
    for (final id in ids)
      if (now.spentIn(id) != last.spentIn(id))
        (
          categoryId: id,
          nowPaise: now.spentIn(id),
          beforePaise: last.spentIn(id),
        ),
  ];
  return changes..sort(
    (a, b) => (b.nowPaise - b.beforePaise).abs().compareTo(
      (a.nowPaise - a.beforePaise).abs(),
    ),
  );
}

List<String> _newShops(DateTime start, List<Txn> txns, List<Txn> spends) {
  final earlier = [
    for (final txn in txns)
      if (txn.occurredAt.isBefore(start) && txn.isSpend) txn,
  ];
  if (earlier.isEmpty) return const [];
  final seen = {for (final txn in earlier) ?shopKey(txn.merchant)};
  final fresh = <String, String>{};
  for (final txn in spends) {
    final key = shopKey(txn.merchant);
    if (key != null && !seen.contains(key)) fresh[key] ??= _nameOf(txn);
  }
  return fresh.values.toList();
}

SpendPatterns _patterns(
  DateTime start,
  DateTime end,
  DateTime now,
  List<Txn> spends,
) {
  final byWeekday = List.filled(7, 0);
  final byPart = {for (final part in DayPart.values) part: 0};
  var weekday = 0;
  var weekend = 0;
  var smallCount = 0;
  var smallPaise = 0;
  for (final txn in spends) {
    final at = txn.occurredAt;
    byWeekday[at.weekday - 1] += txn.amountPaise;
    byPart[DayPart.of(at)] = byPart[DayPart.of(at)]! + txn.amountPaise;
    if (at.weekday >= DateTime.saturday) {
      weekend += txn.amountPaise;
    } else {
      weekday += txn.amountPaise;
    }
    if (txn.amountPaise < smallSpendPaise) {
      smallCount++;
      smallPaise += txn.amountPaise;
    }
  }
  // Days so far: the whole month once it's over.
  final last = now.isBefore(end) ? dayStart(now) : dayStart(end).subtract(
    const Duration(days: 1),
  );
  var weekdays = 0;
  var weekendDays = 0;
  for (
    var day = start;
    !day.isAfter(last);
    day = DateTime(day.year, day.month, day.day + 1)
  ) {
    if (day.weekday >= DateTime.saturday) {
      weekendDays++;
    } else {
      weekdays++;
    }
  }
  return (
    byWeekdayPaise: byWeekday,
    byPartPaise: byPart,
    weekdayAveragePaise: weekday ~/ math.max(1, weekdays),
    weekendAveragePaise: weekend ~/ math.max(1, weekendDays),
    smallCount: smallCount,
    smallPaise: smallPaise,
  );
}
