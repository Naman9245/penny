/// One month's totals, in paise.
class MonthSummary {
  const MonthSummary({
    this.spentPaise = 0,
    this.gotPaise = 0,
    this.investedPaise = 0,
    int? leftPaise,
  }) : leftPaise = leftPaise ?? gotPaise - spentPaise - investedPaise;

  static const empty = MonthSummary();

  /// Spending, with what came back taken off.
  final int spentPaise;

  /// Income only.
  final int gotPaise;

  /// Put away: not spent, but not left either.
  final int investedPaise;

  /// What came in, less what went out.
  final int leftPaise;

  /// "Left" means nothing until some income is logged.
  bool get hasIncome => gotPaise > 0;
}
