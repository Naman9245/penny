import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/money_kinds.dart';

// Penny's mood, worked out on the phone from the budget and the month's
// entries. It's never stored: it always follows from them. One rule gives
// every day its mood and Home shows today's, so the two always agree.

/// The share of a budget, in percent, at which Penny starts to worry.
const _worriedAtPercent = 85;

/// Penny's spending moods, best first. A day gets the worse of two.
const _levels = [PennyMood.happy, PennyMood.worried, PennyMood.sad];

/// Whether [categoryId]'s spending counts towards the everyday budget: it
/// has an amount of its own, and isn't paid in one go.
bool _everyday(Budget budget, String categoryId) =>
    budget.byCategory.containsKey(categoryId) &&
    !categoryById(categoryId).oneGo;

/// How [spent] stands against an [amount] above zero, as an index into
/// [_levels]: within it, at 85% of it, or over it.
int _against(int spent, int amount) => spent > amount
    ? 2
    : spent * 100 >= amount * _worriedAtPercent
    ? 1
    : 0;

/// The everyday budget's share for one day of a month that long, to the
/// rupee.
int _share(int everydayPaise, int daysInMonth) =>
    (everydayPaise / daysInMonth / 100).round() * 100;

/// Where a month stands against the budget.
@immutable
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spentByCategory,
    required this.month,
    required this.day,
    required this.daysInMonth,
    this.todaySpentPaise = 0,
  });

  final Budget budget;

  /// The 1st of the month this is for.
  final DateTime month;

  /// The month's spending per category id.
  final Map<String, int> spentByCategory;

  /// How far into the month it is: today's date, or its last day once the
  /// month is over.
  final int day;
  final int daysInMonth;

  /// Today's spending in the everyday categories that have a budget, which
  /// today's mood goes by.
  final int todaySpentPaise;

  int spentIn(String categoryId) => spentByCategory[categoryId] ?? 0;

  /// Spending in the everyday categories that have a budget. Categories
  /// without one aren't counted.
  int get everydaySpentPaise => spentByCategory.entries
      .where((entry) => _everyday(budget, entry.key))
      .fold(0, (sum, entry) => sum + entry.value);

  int get daysLeft => daysInMonth - day;

  /// The everyday budget's share for one day, to the rupee.
  int get sharePaise => _share(budget.everydayPaise, daysInMonth);

  /// An everyday category over its budget or near it, in words: part of
  /// why Penny feels as she does.
  String? get categoryNote {
    final amounts = [
      for (final amount in budget.byCategory.entries)
        if (!categoryById(amount.key).oneGo) amount,
    ];
    for (final level in const [2, 1]) {
      for (final amount in amounts) {
        if (_against(spentIn(amount.key), amount.value) != level) continue;
        final label = categoryById(amount.key).label;
        return level == 2
            ? '$label is over its budget'
            : '$label is near its budget';
      }
    }
    return null;
  }

  /// A category paid in one go, like rent, that went over its budget, in
  /// words. It doesn't change Penny's mood, which follows everyday spending.
  String? get oneGoNote {
    for (final amount in budget.byCategory.entries) {
      final category = categoryById(amount.key);
      final over = spentIn(amount.key) - amount.value;
      if (category.oneGo && over > 0) {
        return '${category.label} went ${formatPaise(over)} over its budget';
      }
    }
    return null;
  }

  /// Where the month is heading at the everyday pace so far, in words:
  /// against the everyday budget when there is one. Only from the 3rd to
  /// the second-last day, once there's everyday spending to go by. Worked
  /// out here, never by the AI.
  String? get forecast {
    if (day < 3 || day >= daysInMonth) return null;
    final everyday = budget.everydayPaise;
    // With an everyday budget, the categories it covers; without one,
    // everything not paid in one go.
    final spent = everyday > 0
        ? everydaySpentPaise
        : spentByCategory.entries
              .where((entry) => !categoryById(entry.key).oneGo)
              .fold(0, (sum, entry) => sum + entry.value);
    if (spent <= 0) return null;

    final pace = 'At ${formatPaise(_toRupee(spent / day))} a day';
    final monthEnd = spent * daysInMonth / day;
    if (everyday <= 0) {
      return '$pace, about ${formatPaise(_toHundred(monthEnd))} this month';
    }
    if (spent < everyday && monthEnd > everyday) {
      final runsOut = DateTime(
        month.year,
        month.month,
        (everyday * day / spent).ceil(),
      );
      return '$pace, your everyday budget runs out around '
          '${DateFormat('d MMM').format(runsOut)}';
    }
    final spare = _toHundred(everyday - monthEnd);
    return switch (spare) {
      > 0 =>
        "$pace, you'll end with ${formatPaise(spare)} of your everyday "
            'budget to spare',
      < 0 =>
        "$pace, you'll end about ${formatPaise(-spare)} over your "
            'everyday budget',
      _ => "$pace, you'll end right at your everyday budget",
    };
  }

  static int _toRupee(double paise) => (paise / 100).round() * 100;

  static int _toHundred(double paise) => (paise / 10000).round() * 10000;
}

/// How [month] stands against [budget], from its entries, as of [now].
BudgetStatus budgetStatus({
  required Budget budget,
  required Iterable<Txn> monthTxns,
  required DateTime month,
  required DateTime now,
}) {
  final start = monthStart(month);
  final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
  final day = now.isBefore(start)
      ? 0
      : now.isBefore(nextMonth(start))
      ? now.day
      : daysInMonth;
  final today = dayStart(now);
  // Today goes by what was paid today; the month by what's left once
  // paybacks come off.
  var spentToday = 0;
  for (final txn in monthTxns) {
    if (txn.isSpend &&
        dayStart(txn.occurredAt) == today &&
        _everyday(budget, txn.categoryId)) {
      spentToday += txn.amountPaise;
    }
  }
  return BudgetStatus(
    budget: budget,
    spentByCategory: MoneyTotals.of(monthTxns).spentByCategory,
    month: start,
    day: day,
    daysInMonth: daysInMonth,
    todaySpentPaise: spentToday,
  );
}

/// The everyday budget's share for one day of [month], to the rupee.
int dailySharePaise(int everydayPaise, DateTime month) =>
    _share(everydayPaise, DateTime(month.year, month.month + 1, 0).day);

/// How the daily share of [month] is worked out, in words.
String shareExplained(int everydayPaise, DateTime month) {
  final days = DateTime(month.year, month.month + 1, 0).day;
  return 'Your everyday budget, ${formatPaise(everydayPaise)}, ÷ $days days. '
      'Rent, EMIs and other one-go costs stay out of it.';
}

/// One day of a month as Penny sees it, each as an index into [_levels]:
/// how its spending in the budgeted everyday categories stands against its
/// share, and how the month so far stands, with what decided that.
typedef _Day = ({int ofShare, int soFar, String? soFarNote});

/// Every day of [month], first to last, from its entries. A day's own
/// spending is what was paid that day; the month so far has what came back
/// taken off.
List<_Day> _walk(Budget budget, Iterable<Txn> monthTxns, DateTime month) {
  final start = monthStart(month);
  final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
  List<Map<String, int>> days() => [
    for (var day = 0; day <= daysInMonth; day++) <String, int>{},
  ];
  final paidByDay = days();
  final backByDay = days();
  for (final txn in monthTxns) {
    final at = txn.occurredAt;
    if (!_everyday(budget, txn.categoryId) || monthStart(at) != start) {
      continue;
    }
    final into = switch (txn.kind) {
      MoneyKind.spent => paidByDay[at.day],
      MoneyKind.paidBack => backByDay[at.day],
      MoneyKind.got || MoneyKind.invested => null,
    };
    if (into == null) continue;
    into[txn.categoryId] = (into[txn.categoryId] ?? 0) + txn.amountPaise;
  }

  final everyday = budget.everydayPaise;
  final paidSoFar = <String, int>{};
  final backSoFar = <String, int>{};
  final walked = <_Day>[];
  for (var day = 1; day <= daysInMonth; day++) {
    var spent = 0;
    for (final MapEntry(key: id, value: paise) in paidByDay[day].entries) {
      paidSoFar[id] = (paidSoFar[id] ?? 0) + paise;
      spent += paise;
    }
    for (final MapEntry(key: id, value: paise) in backByDay[day].entries) {
      backSoFar[id] = (backSoFar[id] ?? 0) + paise;
    }
    final soFar = {
      for (final MapEntry(key: id, value: paid) in paidSoFar.entries)
        id: math.max(0, paid - (backSoFar[id] ?? 0)),
    };
    // The share is everyday ÷ days in the month; compare without dividing.
    final scaled = spent * daysInMonth;
    final standing = _monthSoFar(budget, soFar);
    walked.add((
      ofShare: scaled <= everyday
          ? 0
          : scaled * 2 <= everyday * 3
          ? 1
          : 2,
      soFar: standing.level,
      soFarNote: standing.note,
    ));
  }
  return walked;
}

/// How the month so far stands, as an index into [_levels], with what
/// decided it in words: worried at 85% of the everyday budget, sad over it
/// or once any everyday category is over its own amount. A category only
/// near its amount is a note on Home instead, or one big buy would tint
/// the rest of the month.
({int level, String? note}) _monthSoFar(Budget budget, Map<String, int> spent) {
  var total = 0;
  String? categoryOver;
  for (final MapEntry(key: id, value: amount) in budget.byCategory.entries) {
    if (categoryById(id).oneGo) continue;
    final its = spent[id] ?? 0;
    total += its;
    if (categoryOver == null && its > amount) {
      categoryOver =
          '${categoryById(id).label} so far: ${formatPaise(its)} of '
          '${formatPaise(amount)}';
    }
  }
  final everyday = budget.everydayPaise;
  final level = everyday == 0 ? 0 : _against(total, everyday);
  String whole() =>
      'Everyday budget so far: ${formatPaise(total)} of '
      '${formatPaise(everyday)}';
  if (level == 2) return (level: 2, note: whole());
  if (categoryOver != null) return (level: 2, note: categoryOver);
  return (level: level, note: level == 1 ? whole() : null);
}

/// Penny's mood on each day of [month] that has one, by day of the month:
/// the worse of how that day went and where the month stood by its end.
/// - The day's spending in the budgeted everyday categories against its
///   share of their budget: happy at or under it, worried up to one and a
///   half times it, sad above that.
/// - The month so far: worried at 85% of the everyday budget, sad over it
///   or once any everyday category is over its own amount.
///
/// A day a goal was reached is celebrating. Rent and the rest paid in one
/// go never count. Days after [now] have none, nor do days before
/// [firstEntry] other than today, and without an everyday budget only goal
/// days do. Home shows today's.
Map<int, PennyMood> dayMoods({
  required Budget budget,
  required Iterable<Txn> monthTxns,
  required DateTime month,
  required DateTime now,
  DateTime? firstEntry,
  Set<DateTime> goalDays = const {},
}) {
  final start = monthStart(month);
  final today = dayStart(now);
  final first = firstEntry == null ? null : dayStart(firstEntry);
  final budgeted = budget.everydayPaise > 0;
  final moods = <int, PennyMood>{};
  for (final (i, day) in _walk(budget, monthTxns, start).indexed) {
    final date = DateTime(start.year, start.month, i + 1);
    if (date.isAfter(today)) break;
    // Days before the first entry have nothing to say, but today always
    // does.
    final started = first != null && !date.isBefore(first);
    if (goalDays.contains(date)) {
      moods[i + 1] = PennyMood.celebrating;
    } else if (budgeted && (started || date == today)) {
      moods[i + 1] = _levels[math.max(day.ofShare, day.soFar)];
    }
  }
  return moods;
}

/// Why [date] is worse than its own spending, when the month so far made
/// it so: like "Food so far: ₹2,100 of ₹2,000". Null when the day's own
/// spending decided its mood.
String? monthNoteOn({
  required Budget budget,
  required Iterable<Txn> monthTxns,
  required DateTime date,
}) {
  if (budget.everydayPaise == 0) return null;
  final day = _walk(budget, monthTxns, date)[date.day - 1];
  return day.soFar > day.ofShare ? day.soFarNote : null;
}

/// A day's money the way Penny counts it: spending in the budgeted everyday
/// categories her mood goes by, in everyday ones without a budget, and paid
/// in one go; then what came back and what was put away, which never change
/// a day's face.
typedef DaySpending = ({
  int counted,
  int noBudget,
  int oneGo,
  int cameBack,
  int invested,
});

DaySpending splitDaySpending(Budget budget, Iterable<Txn> entries) {
  var counted = 0;
  var noBudget = 0;
  var oneGo = 0;
  var cameBack = 0;
  var invested = 0;
  for (final txn in entries) {
    switch (txn.kind) {
      case MoneyKind.got:
        break;
      case MoneyKind.paidBack:
        cameBack += txn.amountPaise;
      case MoneyKind.invested:
        invested += txn.amountPaise;
      case MoneyKind.spent when categoryById(txn.categoryId).oneGo:
        oneGo += txn.amountPaise;
      case MoneyKind.spent when _everyday(budget, txn.categoryId):
        counted += txn.amountPaise;
      case MoneyKind.spent:
        noBudget += txn.amountPaise;
    }
  }
  return (
    counted: counted,
    noBudget: noBudget,
    oneGo: oneGo,
    cameBack: cameBack,
    invested: invested,
  );
}

/// How a month's days went: how many had each mood, and the spending mood
/// most of them had. Null when no day has a mood yet.
({PennyMood mostly, Map<PennyMood, int> counts})? moodSummary(
  Map<int, PennyMood> moods,
) {
  if (moods.isEmpty) return null;
  final counts = <PennyMood, int>{};
  for (final mood in moods.values) {
    counts[mood] = (counts[mood] ?? 0) + 1;
  }
  // Goal days are a treat, not a habit, so "mostly" is about spending; a
  // tie goes to the kinder mood.
  PennyMood? mostly;
  for (final mood in _levels) {
    final count = counts[mood] ?? 0;
    if (count > 0 && (mostly == null || count > counts[mostly]!)) mostly = mood;
  }
  return (mostly: mostly ?? PennyMood.celebrating, counts: counts);
}

/// "18 days left", "1 day left" or "Last day".
String daysLeftLabel(int daysLeft) => switch (daysLeft) {
  <= 0 => 'Last day',
  1 => '1 day left',
  _ => '$daysLeft days left',
};
