import 'package:penny/services/money_kinds.dart';

/// One category's money in a month, in paise.
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.kind,
    required this.totalPaise,
    required this.count,
    this.paidBackPaise = 0,
  });

  final String categoryId;

  /// Spent, got or invested. What came back counts in its spend category.
  final MoneyKind kind;

  /// For spending, what was paid less what came back, never below zero.
  final int totalPaise;

  /// How many entries were paid or got.
  final int count;

  /// What came back, for a spend category.
  final int paidBackPaise;
}

/// Spending and income for one month, in paise, as Home counts them.
class MonthTotals {
  const MonthTotals({
    required this.month,
    this.spentPaise = 0,
    this.gotPaise = 0,
  });

  /// The 1st of the month, at midnight.
  final DateTime month;
  final int spentPaise;
  final int gotPaise;
}
