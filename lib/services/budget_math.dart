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
        return '${category.label} went ${formatTotal(over)} over its budget';
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
  return 'Your everyday budget, ${formatTotal(everydayPaise)}, ÷ $days days. '
      'Rent, EMIs and other one-go costs stay out of it.';
}

/// How [spent] over [days] days stands against the daily share of an
/// [everyday] budget for a month [daysInMonth] long, as an index into
/// [_levels]: at or under the share, up to one and a half times it, or
/// more.
int _againstShare(int spent, int days, int everyday, int daysInMonth) {
  // The share is everyday ÷ days in the month; compare without dividing.
  final scaled = spent * daysInMonth;
  final allowed = everyday * days;
  return scaled <= allowed
      ? 0
      : scaled * 2 <= allowed * 3
      ? 1
      : 2;
}

/// Every day of [month], first to last, as an index into [_levels]: what
/// was paid that day in the budgeted everyday categories, against the
/// day's share. Nothing else colours a day: not the month so far, nor a
/// category over its budget, nor money that came back later.
List<int> _dayLevels(Budget budget, Iterable<Txn> monthTxns, DateTime month) {
  final start = monthStart(month);
  final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
  final paid = List.filled(daysInMonth + 1, 0);
  for (final txn in monthTxns) {
    final at = txn.occurredAt;
    if (txn.isSpend &&
        _everyday(budget, txn.categoryId) &&
        monthStart(at) == start) {
      paid[at.day] += txn.amountPaise;
    }
  }
  final everyday = budget.everydayPaise;
  return [
    for (var day = 1; day <= daysInMonth; day++)
      _againstShare(paid[day], 1, everyday, daysInMonth),
  ];
}

/// Penny's mood on each day of [month] that has one, by day of the month:
/// that day's spending in the budgeted everyday categories against its
/// share of their budget. Happy at or under it, so a day with nothing spent
/// is happy; worried up to one and a half times it; sad above that. How the
/// month is going shows on its own card and on Home, never on a day.
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
  for (final (i, level) in _dayLevels(budget, monthTxns, start).indexed) {
    final date = DateTime(start.year, start.month, i + 1);
    if (date.isAfter(today)) break;
    // Days before the first entry have nothing to say, but today always
    // does.
    final started = first != null && !date.isBefore(first);
    if (goalDays.contains(date)) {
      moods[i + 1] = PennyMood.celebrating;
    } else if (budgeted && (started || date == today)) {
      moods[i + 1] = _levels[level];
    }
  }
  return moods;
}

/// How a month went, for the card under the mood calendar.
typedef MonthMood = ({
  /// Happy, worried or sad: the face most days had.
  PennyMood mood,

  /// Everyday spending on the days that have a face, as Home counts it.
  int spentPaise,

  /// How many days had each face.
  Map<PennyMood, int> counts,

  /// Each everyday category over its budget, then each near it, like
  /// "Groceries: ₹2,174 of ₹2,000".
  List<String> categoryNotes,
});

/// [month]'s mood from its days' faces in [moods]: the face most of them
/// had, of happy, worried and sad, so a month of happy days with a few sad
/// ones is happy. A tie goes to the worse face, and goal days count for
/// neither. With it, the everyday spending of the days that have a face,
/// with what came back taken off as on Home. Null without an everyday
/// budget, or before any day has a face.
MonthMood? monthMood({
  required Budget budget,
  required Iterable<Txn> monthTxns,
  required DateTime month,
  required Map<int, PennyMood> moods,
}) {
  final everyday = budget.everydayPaise;
  if (everyday == 0 || moods.isEmpty) return null;
  final start = monthStart(month);
  final inMonth = [
    for (final txn in monthTxns)
      if (monthStart(txn.occurredAt) == start) txn,
  ];
  final spent =
      MoneyTotals.of([
            for (final txn in inMonth)
              if (moods.containsKey(txn.occurredAt.day)) txn,
          ]).spentByCategory.entries
          .where((entry) => _everyday(budget, entry.key))
          .fold(0, (sum, entry) => sum + entry.value);

  final counts = <PennyMood, int>{};
  for (final mood in moods.values) {
    counts[mood] = (counts[mood] ?? 0) + 1;
  }
  // Best to worst, so a later face with as many days wins the tie.
  var mood = PennyMood.happy;
  var most = 0;
  for (final face in const [
    PennyMood.happy,
    PennyMood.worried,
    PennyMood.sad,
  ]) {
    final days = counts[face] ?? 0;
    if (days > 0 && days >= most) {
      mood = face;
      most = days;
    }
  }

  final byCategory = MoneyTotals.of(inMonth).spentByCategory;
  final notes = [
    for (final level in const [2, 1])
      for (final MapEntry(key: id, value: amount) in budget.byCategory.entries)
        if (!categoryById(id).oneGo &&
            _against(byCategory[id] ?? 0, amount) == level)
          '${categoryById(id).label}: ${formatTotal(byCategory[id] ?? 0)} of '
              '${formatTotal(amount)}',
  ];

  return (mood: mood, spentPaise: spent, counts: counts, categoryNotes: notes);
}

/// What Penny says on Home, about today: by today's face, and whether
/// anything counted was spent today. How the month is going is in the box
/// under it.
String homeLine(PennyMood mood, {required int todaySpentPaise}) =>
    switch (mood) {
      PennyMood.happy when todaySpentPaise == 0 => 'Nothing spent today. Nice!',
      PennyMood.happy => "Today's within your share. Keep it up!",
      PennyMood.worried => "Today's a bit over your share.",
      PennyMood.sad => "Today went well over your share. Let's plan a fix!",
      _ => mood.line,
    };

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

/// "18 days left", "1 day left" or "Last day".
String daysLeftLabel(int daysLeft) => switch (daysLeft) {
  <= 0 => 'Last day',
  1 => '1 day left',
  _ => '$daysLeft days left',
};
