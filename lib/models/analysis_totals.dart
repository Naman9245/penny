import 'package:penny/models/txn_enums.dart';

/// One category's money in a month, in paise.
class CategoryTotal {
  const CategoryTotal({
    required this.categoryId,
    required this.type,
    required this.totalPaise,
    required this.count,
  });

  final String categoryId;
  final TxnType type;
  final int totalPaise;

  /// How many entries make up [totalPaise].
  final int count;
}

/// Money out and in for one month, in paise.
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
