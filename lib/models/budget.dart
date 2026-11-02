import 'package:flutter/foundation.dart';

/// What the user means to spend each month, in paise: one everyday budget
/// for everything but the categories paid in one go, and caps for single
/// categories.
@immutable
class Budget {
  const Budget({this.everydayPaise, this.caps = const {}});

  static const none = Budget();

  final int? everydayPaise;

  /// Category id → that category's monthly cap.
  final Map<String, int> caps;

  bool get isEmpty => everydayPaise == null && caps.isEmpty;
}
