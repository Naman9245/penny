import 'package:flutter/painting.dart';

/// Penny's palette. Pastels carry meaning (mood, category); ink draws every
/// border, shadow and line of text.
abstract final class AppColors {
  static const yellow = Color(0xFFFFD84D);
  static const lavender = Color(0xFFB8A6FF);
  static const pink = Color(0xFFFFB6D7);
  static const mint = Color(0xFFB8F3C6);
  static const sky = Color(0xFFA9E5FF);
  static const cream = Color(0xFFFFF8EC);
  static const ink = Color(0xFF1A1A1A);
  static const white = Color(0xFFFFFFFF);

  /// Secondary text on cream and white (6.7:1 on cream).
  static const inkMuted = Color(0xFF5E574F);

  /// Hairlines between rows inside a card.
  static const hairline = Color(0x261A1A1A);

  /// Money in. Mint is too pale for text, so amounts use this green.
  static const positive = Color(0xFF1B7A3D);

  /// Money short: a negative "left", and later, over-budget numbers.
  static const negative = Color(0xFFC62828);

  /// The inner ring that makes Penny read as a coin.
  static const coinRim = Color(0xFFEFC139);
}
