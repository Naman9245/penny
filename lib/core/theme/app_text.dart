import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';

/// Type scale. Baloo 2 (chunky and rounded, like Penny) for money; DM Sans
/// for headings and everything you read. Both cover ₹.
abstract final class AppText {
  static const displayFamily = 'Baloo2';
  static const bodyFamily = 'DMSans';

  /// The amount being typed and the month's spend.
  static const hero = TextStyle(
    fontFamily: displayFamily,
    fontSize: 44,
    fontWeight: FontWeight.w800,
    height: 1.05,
    color: AppColors.ink,
  );
  static const h1 = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );
  static const h2 = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );
  static const h3 = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  /// Totals on the smaller stat cards.
  static const amount = TextStyle(
    fontFamily: displayFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.1,
    color: AppColors.ink,
  );
  static const snack = TextStyle(
    fontFamily: displayFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.cream,
  );

  static const body = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.ink,
  );
  static const bodyMuted = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.35,
    color: AppColors.inkMuted,
  );
  static const bodyStrong = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.ink,
  );

  /// Buttons and card labels.
  static const label = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.ink,
  );

  /// Chips and small pills.
  static const chip = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 13.5,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.ink,
  );

  /// Names under category tiles.
  static const caption = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.ink,
  );

  /// Secondary lines: times, hints.
  static const small = TextStyle(
    fontFamily: bodyFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.inkMuted,
  );

  /// The same scale, for Material widgets such as the date picker.
  static const textTheme = TextTheme(
    displayLarge: hero,
    headlineLarge: h1,
    headlineMedium: h2,
    titleLarge: h3,
    titleMedium: bodyStrong,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: small,
    labelLarge: label,
    labelMedium: chip,
    labelSmall: caption,
  );
}
