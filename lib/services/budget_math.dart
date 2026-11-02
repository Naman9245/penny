import 'package:flutter/foundation.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/txn_enums.dart';

// Penny's mood, worked out on the phone from the budget and the month's
// entries. Never stored, as the brief's DailyMood rule says.

/// The share of a budget, in percent, at which Penny starts to worry.
const _worriedAtPercent = 85;

/// Whether [categoryId]'s spending counts towards the everyday budget: it
/// has an amount of its own, and isn't paid in one go.
bool _everyday(Budget budget, String categoryId) =>
    budget.byCategory.containsKey(categoryId) &&
    !categoryById(categoryId).oneGo;

/// Where a month stands against the budget.
@immutable
class BudgetStatus {
  const BudgetStatus({
    required this.budget,
    required this.spentByCategory,
    required this.day,
    required this.daysInMonth,
  });

  final Budget budget;

  /// The month's spending per category id.
  final Map<String, int> spentByCategory;

  /// How far into the month it is: today's date, or its last day once the
  /// month is over.
  final int day;
  final int daysInMonth;

  int spentIn(String categoryId) => spentByCategory[categoryId] ?? 0;

  /// Spending in the everyday categories that have a budget. Categories
  /// without one aren't counted.
  int get everydaySpentPaise => spentByCategory.entries
      .where((entry) => _everyday(budget, entry.key))
      .fold(0, (sum, entry) => sum + entry.value);

  int get daysLeft => daysInMonth - day;

  /// The category Penny's mood is about, in words, when one is over its
  /// budget or near it.
  String? get categoryNote {
    final amounts = budget.byCategory.entries;
    for (final amount in amounts) {
      if (spentIn(amount.key) > amount.value) {
        return '${categoryById(amount.key).label} is over its budget';
      }
    }
    for (final amount in amounts) {
      final category = categoryById(amount.key);
      if (!category.oneGo &&
          spentIn(amount.key) * 100 >= amount.value * _worriedAtPercent) {
        return '${category.label} is near its budget';
      }
    }
    return null;
  }

  /// The first of these that holds: over a budget, near one, under the
  /// everyday budget's pace, or none of those.
  PennyMood get mood {
    if (budget.isEmpty) return PennyMood.neutral;
    final everyday = budget.everydayPaise;
    final spent = everydaySpentPaise;
    final amounts = budget.byCategory.entries;

    final over =
        spent > everyday ||
        amounts.any((amount) => spentIn(amount.key) > amount.value);
    if (over) return PennyMood.sad;

    // Rent or a bill uses its whole budget in one go, which is no worry.
    final near =
        (everyday > 0 && spent * 100 >= everyday * _worriedAtPercent) ||
        amounts.any(
          (amount) =>
              !categoryById(amount.key).oneGo &&
              spentIn(amount.key) * 100 >= amount.value * _worriedAtPercent,
        );
    if (near) return PennyMood.worried;

    if (everyday == 0) return PennyMood.happy;
    final onPace = spent * daysInMonth <= everyday * day;
    return onPace ? PennyMood.happy : PennyMood.neutral;
  }
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
  final spent = <String, int>{};
  for (final txn in monthTxns) {
    if (txn.type != TxnType.debit) continue;
    spent[txn.categoryId] = (spent[txn.categoryId] ?? 0) + txn.amountPaise;
  }
  return BudgetStatus(
    budget: budget,
    spentByCategory: spent,
    day: day,
    daysInMonth: daysInMonth,
  );
}

/// The everyday budget's share for one day of [month], to the rupee.
int dailySharePaise(int everydayPaise, DateTime month) {
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  return (everydayPaise / daysInMonth / 100).round() * 100;
}

/// Penny's mood on each day of [month] that has one, by day of the month.
/// It is that day's spending in the budgeted everyday categories against
/// the day's share of their budget: happy at or under it, worried up to
/// one and a half times it, sad above that. A day a goal was reached is
/// celebrating. Days after [now] or before [firstEntry] have none, and
/// without an everyday budget only goal days do.
Map<int, PennyMood> dayMoods({
  required Budget budget,
  required Iterable<Txn> monthTxns,
  required DateTime month,
  required DateTime now,
  DateTime? firstEntry,
  Set<DateTime> goalDays = const {},
}) {
  final start = monthStart(month);
  final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
  final spent = List.filled(daysInMonth + 1, 0);
  for (final txn in monthTxns) {
    final at = txn.occurredAt;
    if (txn.type != TxnType.debit ||
        !_everyday(budget, txn.categoryId) ||
        monthStart(at) != start) {
      continue;
    }
    spent[at.day] += txn.amountPaise;
  }

  final today = dayStart(now);
  final first = firstEntry == null ? null : dayStart(firstEntry);
  final everyday = budget.everydayPaise;
  final moods = <int, PennyMood>{};
  for (var day = 1; day <= daysInMonth; day++) {
    final date = DateTime(start.year, start.month, day);
    if (date.isAfter(today)) break;
    if (goalDays.contains(date)) {
      moods[day] = PennyMood.celebrating;
      continue;
    }
    if (everyday == 0 || first == null || date.isBefore(first)) continue;
    // The day's share is everyday ÷ days in the month; compare without
    // dividing.
    final scaled = spent[day] * daysInMonth;
    moods[day] = scaled <= everyday
        ? PennyMood.happy
        : scaled * 2 <= everyday * 3
        ? PennyMood.worried
        : PennyMood.sad;
  }
  return moods;
}

/// "18 days left", "1 day left" or "Last day".
String daysLeftLabel(int daysLeft) => switch (daysLeft) {
  <= 0 => 'Last day',
  1 => '1 day left',
  _ => '$daysLeft days left',
};
