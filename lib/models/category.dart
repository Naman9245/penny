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
    id: 'subscriptions',
    label: 'Subscriptions',
    emoji: '📺',
    color: AppColors.pink,
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
    id: 'education',
    label: 'Education',
    emoji: '📚',
    color: AppColors.yellow,
    type: TxnType.debit,
    oneGo: true,
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
    id: 'other_income',
    label: 'Other',
    emoji: '🪙',
    color: AppColors.pink,
    type: TxnType.credit,
  ),
];

/// Money put away rather than spent: SIPs, mutual funds, shares. It stays
/// out of Spent, the budget and Penny's mood, so it's not among
/// [spendCategories]. Must match INVEST_ID in
/// supabase/functions/_shared/month.ts.
const investCategory = Category(
  id: 'invest',
  label: 'Invest / SIP',
  emoji: '📈',
  color: AppColors.mint,
  type: TxnType.debit,
);

/// The tiles for [type], in order. Money out puts Invest / SIP just before
/// Other.
List<Category> categoriesFor(TxnType type) => switch (type) {
  TxnType.debit => [
    ...spendCategories.take(spendCategories.length - 1),
    investCategory,
    spendCategories.last,
  ],
  TxnType.credit => incomeCategories,
};

final _byId = {
  for (final category in [
    ...spendCategories,
    investCategory,
    ...incomeCategories,
  ])
    category.id: category,
};

final _spendIds = {for (final category in spendCategories) category.id};

/// Whether [id] is one of [spendCategories]: one that budgets, moods and
/// paybacks go by.
bool isSpendCategory(String? id) => _spendIds.contains(id);

/// Ids this version doesn't know (say, from a newer one) show as Other.
Category categoryById(String id) => _byId[id] ?? spendCategories.last;
