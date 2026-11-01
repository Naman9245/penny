/// One month's totals, in paise.
class MonthSummary {
  const MonthSummary({this.spentPaise = 0, this.gotPaise = 0});

  static const empty = MonthSummary();

  final int spentPaise;
  final int gotPaise;

  int get leftPaise => gotPaise - spentPaise;

  /// "Left" means nothing until some income is logged.
  bool get hasIncome => gotPaise > 0;
}
