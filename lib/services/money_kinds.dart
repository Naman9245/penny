import 'dart:math' as math;

import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/analysis_totals.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/txn_enums.dart';

// One rule for what each entry is, which every total follows, so Home,
// Analysis, the budget, Penny's mood and what Penny is told all agree. Must
// match supabase/functions/_shared/month.ts.

/// What an entry is.
enum MoneyKind {
  /// Money out, in a spend category.
  spent,

  /// Money in, in an income category.
  got,

  /// Money in, in a spend category: a friend paying back their share. It
  /// takes that category's spending down, never below zero, and is never
  /// income.
  paidBack,

  /// Money out, into Invest / SIP: put away, not spent.
  invested;

  static MoneyKind of(TxnType type, String categoryId) => switch (type) {
    TxnType.debit when categoryId == investCategory.id => invested,
    TxnType.debit => spent,
    TxnType.credit when isSpendCategory(categoryId) => paidBack,
    TxnType.credit => got,
  };
}

extension TxnMoneyKind on Txn {
  MoneyKind get kind => MoneyKind.of(type, categoryId);

  /// Spending: what budgets, moods and necessary-or-wasteful are about.
  bool get isSpend => kind == MoneyKind.spent;
}

/// What an entry was for, in words: "Food", or "Food · paid back".
String kindLabel(TxnType type, String categoryId) {
  final label = categoryById(categoryId).label;
  return MoneyKind.of(type, categoryId) == MoneyKind.paidBack
      ? '$label · paid back'
      : label;
}

/// Entries already summed by type and category, as the database gives them.
typedef CategorySum = ({TxnType type, String categoryId, int paise, int count});

/// Money added up by kind, in paise.
class MoneyTotals {
  MoneyTotals._();

  factory MoneyTotals.of(Iterable<Txn> txns) {
    final totals = MoneyTotals._();
    for (final txn in txns) {
      totals._add(txn.type, txn.categoryId, txn.amountPaise);
    }
    return totals;
  }

  factory MoneyTotals.fromSums(Iterable<CategorySum> sums) {
    final totals = MoneyTotals._();
    for (final sum in sums) {
      totals._add(sum.type, sum.categoryId, sum.paise);
    }
    return totals;
  }

  final _paidOut = <String, int>{};
  final _paidBack = <String, int>{};
  final _got = <String, int>{};
  var _invested = 0;

  void _add(TxnType type, String categoryId, int paise) {
    void into(Map<String, int> map) =>
        map[categoryId] = (map[categoryId] ?? 0) + paise;
    switch (MoneyKind.of(type, categoryId)) {
      case MoneyKind.spent:
        into(_paidOut);
      case MoneyKind.paidBack:
        into(_paidBack);
      case MoneyKind.got:
        into(_got);
      case MoneyKind.invested:
        _invested += paise;
    }
  }

  /// Spend categories with anything paid or paid back.
  Set<String> get spendIds => {..._paidOut.keys, ..._paidBack.keys};

  /// A spend category's spending: what was paid less what came back, never
  /// below zero.
  int spentIn(String categoryId) =>
      math.max(0, (_paidOut[categoryId] ?? 0) - (_paidBack[categoryId] ?? 0));

  int paidBackIn(String categoryId) => _paidBack[categoryId] ?? 0;

  Map<String, int> get spentByCategory => {
    for (final id in spendIds) id: spentIn(id),
  };

  /// Spending, with what came back taken off each category.
  int get spentPaise => spendIds.fold(0, (sum, id) => sum + spentIn(id));

  int get paidBackPaise => _sum(_paidBack.values);

  /// Income categories with anything in them.
  Iterable<String> get incomeIds => _got.keys;

  int gotIn(String categoryId) => _got[categoryId] ?? 0;

  /// Income only: what came back isn't income.
  int get gotPaise => _sum(_got.values);

  int get investedPaise => _invested;

  /// Everything that came in, less everything that went out, invested
  /// included. Usually income less spending and investing; more when
  /// something came back to a category with less spent in it so far.
  int get leftPaise =>
      gotPaise + paidBackPaise - _sum(_paidOut.values) - _invested;

  static int _sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
}

/// A month's categories from [sums], biggest first: spending with what came
/// back taken off, income, and what was put away.
List<CategoryTotal> categoryTotalsOf(Iterable<CategorySum> sums) {
  final totals = MoneyTotals.fromSums(sums);
  final counts = <(MoneyKind, String), int>{};
  for (final sum in sums) {
    final key = (MoneyKind.of(sum.type, sum.categoryId), sum.categoryId);
    counts[key] = (counts[key] ?? 0) + sum.count;
  }
  int countOf(MoneyKind kind, String id) => counts[(kind, id)] ?? 0;
  return [
    for (final id in totals.spendIds)
      CategoryTotal(
        categoryId: id,
        kind: MoneyKind.spent,
        totalPaise: totals.spentIn(id),
        count: countOf(MoneyKind.spent, id),
        paidBackPaise: totals.paidBackIn(id),
      ),
    for (final id in totals.incomeIds)
      CategoryTotal(
        categoryId: id,
        kind: MoneyKind.got,
        totalPaise: totals.gotIn(id),
        count: countOf(MoneyKind.got, id),
      ),
    if (countOf(MoneyKind.invested, investCategory.id) > 0)
      CategoryTotal(
        categoryId: investCategory.id,
        kind: MoneyKind.invested,
        totalPaise: totals.investedPaise,
        count: countOf(MoneyKind.invested, investCategory.id),
      ),
  ]..sort((a, b) => b.totalPaise.compareTo(a.totalPaise));
}
