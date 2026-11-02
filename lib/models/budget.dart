import 'package:flutter/foundation.dart' show immutable;
import 'package:penny/models/category.dart';

/// What the user means to spend each month, category by category, in
/// paise. The monthly budget is their total.
@immutable
class Budget {
  const Budget({this.byCategory = const {}});

  static const none = Budget();

  /// Category id → what the user means to spend on it a month.
  final Map<String, int> byCategory;

  bool get isEmpty => byCategory.isEmpty;

  /// The monthly budget: every category's amount together.
  int get totalPaise => byCategory.values.fold(0, (sum, paise) => sum + paise);

  /// The part for everyday spending, which the mood and the calendar go by.
  int get everydayPaise => _sumWhere((category) => !category.oneGo);

  /// The part for what is paid in one go, like rent.
  int get oneGoPaise => _sumWhere((category) => category.oneGo);

  int _sumWhere(bool Function(Category category) keep) => byCategory.entries
      .where((entry) => keep(categoryById(entry.key)))
      .fold(0, (sum, entry) => sum + entry.value);
}
