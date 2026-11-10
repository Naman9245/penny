import 'package:flutter/painting.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/models/txn_enums.dart';

/// A spending or income category. The emoji stands in for its character art.
class Category {
  const Category({
    required this.id,
    required this.label,
    required this.emoji,
    required this.color,
    required this.type,
    this.oneGo = false,
  });

  /// Stored on every transaction, so never rename one.
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final TxnType type;

  /// Paid in one go, like rent, so it stays out of the everyday budget and
  /// its daily share. Must match ONE_GO_IDS in
  /// supabase/functions/_shared/month.ts.
  final bool oneGo;
}

const spendCategories = <Category>[
  Category(
    id: 'food',
    label: 'Food',
    emoji: '🍔',
    color: AppColors.pink,
    type: TxnType.debit,
  ),
  Category(
    id: 'groceries',
    label: 'Groceries',
    emoji: '🛒',
    color: AppColors.mint,
    type: TxnType.debit,
  ),
  Category(
    id: 'travel',
    label: 'Travel',
    emoji: '🚌',
    color: AppColors.sky,
    type: TxnType.debit,
  ),
  Category(
    id: 'fuel',
    label: 'Fuel',
    emoji: '⛽',
    color: AppColors.yellow,
    type: TxnType.debit,
  ),
  Category(
    id: 'shopping',
    label: 'Shopping',
    emoji: '🛍️',
    color: AppColors.lavender,
    type: TxnType.debit,
  ),
  Category(
    id: 'bills',
    label: 'Bills & recharge',
    emoji: '⚡',
    color: AppColors.yellow,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'rent',
    label: 'Rent & PG',
    emoji: '🏠',
    color: AppColors.sky,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'home',
    label: 'Home & upkeep',
    emoji: '🛋️',
    color: AppColors.mint,
    type: TxnType.debit,
  ),
  Category(
    id: 'subscriptions',
    label: 'Subscriptions',
    emoji: '📺',
    color: AppColors.pink,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'emi',
    label: 'EMIs & loans',
    emoji: '📆',
    color: AppColors.lavender,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'charges',
    label: 'Bank charges & fees',
    emoji: '🧾',
    color: AppColors.cream,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'fun',
    label: 'Fun',
    emoji: '🎬',
    color: AppColors.lavender,
    type: TxnType.debit,
  ),
  Category(
    id: 'health',
    label: 'Health',
    emoji: '💊',
    color: AppColors.mint,
    type: TxnType.debit,
  ),
  Category(
    id: 'care',
    label: 'Personal care',
    emoji: '💇',
    color: AppColors.pink,
    type: TxnType.debit,
  ),
  Category(
    id: 'education',
    label: 'Education',
    emoji: '📚',
    color: AppColors.yellow,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'gifts',
    label: 'Gifts & donations',
    emoji: '🎁',
    color: AppColors.lavender,
    type: TxnType.debit,
  ),
  Category(
    id: 'family',
    label: 'Family',
    emoji: '👨‍👩‍👧',
    color: AppColors.sky,
    type: TxnType.debit,
    oneGo: true,
  ),
  Category(
    id: 'people',
    label: 'To people',
    emoji: '🤝',
    color: AppColors.mint,
    type: TxnType.debit,
  ),
  Category(
    id: 'other',
    label: 'Other',
    emoji: '🪙',
    color: AppColors.white,
    type: TxnType.debit,
  ),
];

const incomeCategories = <Category>[
  Category(
    id: 'pocket_money',
    label: 'Pocket money',
    emoji: '👛',
    color: AppColors.yellow,
    type: TxnType.credit,
  ),
  Category(
    id: 'salary',
    label: 'Salary/stipend',
    emoji: '💼',
    color: AppColors.mint,
    type: TxnType.credit,
  ),
  Category(
    id: 'freelance',
    label: 'Freelance',
    emoji: '💻',
    color: AppColors.sky,
    type: TxnType.credit,
  ),
  Category(
    id: 'refund',
    label: 'Refund/cashback',
    emoji: '↩️',
    color: AppColors.lavender,
    type: TxnType.credit,
  ),
  Category(
    id: 'interest',
    label: 'Interest',
    emoji: '💰',
    color: AppColors.yellow,
    type: TxnType.credit,
  ),
  Category(
    id: 'dividends',
    label: 'Dividends',
    emoji: '💹',
    color: AppColors.mint,
    type: TxnType.credit,
  ),
  Category(
    id: 'from_people',
    label: 'From people',
    emoji: '🤝',
    color: AppColors.sky,
    type: TxnType.credit,
  ),
  Category(
    id: 'other_income',
    label: 'Other',
    emoji: '🪙',
    color: AppColors.pink,
    type: TxnType.credit,
  ),
];

/// Money put away rather than spent: mutual funds and SIPs. Its id, from
/// when it was the only kind of investing, stays.
const investCategory = Category(
  id: 'invest',
  label: 'Mutual funds & SIP',
  emoji: '📈',
  color: AppColors.mint,
  type: TxnType.debit,
);

/// The kinds of investing. They stay out of Spent, the budget and Penny's
/// mood, so they're not among [spendCategories], and Penny's server only
/// ever gets them as a total.
const investCategories = <Category>[
  investCategory,
  Category(
    id: 'stocks',
    label: 'Stocks & ETFs',
    emoji: '📊',
    color: AppColors.sky,
    type: TxnType.debit,
  ),
  Category(
    id: 'deposits',
    label: 'FD, RD, PPF & NPS',
    emoji: '🏦',
    color: AppColors.yellow,
    type: TxnType.debit,
  ),
];

/// The tiles for [type], in order. Money out puts the kinds of investing
/// just before Other.
List<Category> categoriesFor(TxnType type) => switch (type) {
  TxnType.debit => [
    ...spendCategories.take(spendCategories.length - 1),
    ...investCategories,
    spendCategories.last,
  ],
  TxnType.credit => incomeCategories,
};

/// Every category, spending, investing then income.
const allCategories = [
  ...spendCategories,
  ...investCategories,
  ...incomeCategories,
];

final _byId = {for (final category in allCategories) category.id: category};

final _spendIds = {for (final category in spendCategories) category.id};
final _investIds = {for (final category in investCategories) category.id};

/// Whether [id] is a kind of investing: money put away, not spent.
bool isInvestCategory(String? id) => _investIds.contains(id);

/// Which spend categories are paid in one go, in words, for the budget
/// screen: "Rent & PG, Bills & recharge, … and Family are paid in one go…".
String get oneGoLine {
  final labels = [
    for (final category in spendCategories)
      if (category.oneGo) category.label,
  ];
  final named = labels.length == 1
      ? labels.single
      : '${labels.sublist(0, labels.length - 1).join(', ')} and '
            '${labels.last}';
  return "$named are paid in one go, so Penny's mood and the calendar go by "
      'everyday spending.';
}

/// Whether [id] is one of [spendCategories]: one that budgets, moods and
/// paybacks go by.
bool isSpendCategory(String? id) => _spendIds.contains(id);

/// Ids this version doesn't know (say, from a newer one) show as Other.
Category categoryById(String id) => _byId[id] ?? spendCategories.last;
