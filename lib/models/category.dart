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
  });

  /// Stored on every transaction, so never rename one.
  final String id;
  final String label;
  final String emoji;
  final Color color;
  final TxnType type;
}

const spendCategories = <Category>[
  Category(id: 'food', label: 'Food', emoji: '🍔', color: AppColors.pink, type: TxnType.debit),
  Category(id: 'groceries', label: 'Groceries', emoji: '🛒', color: AppColors.mint, type: TxnType.debit),
  Category(id: 'travel', label: 'Travel', emoji: '🚌', color: AppColors.sky, type: TxnType.debit),
  Category(id: 'shopping', label: 'Shopping', emoji: '🛍️', color: AppColors.lavender, type: TxnType.debit),
  Category(id: 'bills', label: 'Bills & recharge', emoji: '⚡', color: AppColors.yellow, type: TxnType.debit),
  Category(id: 'rent', label: 'Rent & PG', emoji: '🏠', color: AppColors.sky, type: TxnType.debit),
  Category(id: 'subscriptions', label: 'Subscriptions', emoji: '📺', color: AppColors.pink, type: TxnType.debit),
  Category(id: 'fun', label: 'Fun', emoji: '🎬', color: AppColors.lavender, type: TxnType.debit),
  Category(id: 'health', label: 'Health', emoji: '💊', color: AppColors.mint, type: TxnType.debit),
  Category(id: 'education', label: 'Education', emoji: '📚', color: AppColors.yellow, type: TxnType.debit),
  Category(id: 'other', label: 'Other', emoji: '🪙', color: AppColors.white, type: TxnType.debit),
];

const incomeCategories = <Category>[
  Category(id: 'pocket_money', label: 'Pocket money', emoji: '👛', color: AppColors.yellow, type: TxnType.credit),
  Category(id: 'salary', label: 'Salary/stipend', emoji: '💼', color: AppColors.mint, type: TxnType.credit),
  Category(id: 'freelance', label: 'Freelance', emoji: '💻', color: AppColors.sky, type: TxnType.credit),
  Category(id: 'refund', label: 'Refund/cashback', emoji: '↩️', color: AppColors.lavender, type: TxnType.credit),
  Category(id: 'other_income', label: 'Other', emoji: '🪙', color: AppColors.pink, type: TxnType.credit),
];

List<Category> categoriesFor(TxnType type) =>
    type == TxnType.debit ? spendCategories : incomeCategories;

final _byId = {
  for (final category in [...spendCategories, ...incomeCategories])
    category.id: category,
};

/// Ids this version doesn't know (say, from a newer one) show as Other.
Category categoryById(String id) => _byId[id] ?? spendCategories.last;
