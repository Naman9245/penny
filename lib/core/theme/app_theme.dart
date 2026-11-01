import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';

/// Light only for now: the pastel palette is designed for a cream page.
ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.yellow,
    onPrimary: AppColors.ink,
    secondary: AppColors.lavender,
    onSecondary: AppColors.ink,
    tertiary: AppColors.pink,
    onTertiary: AppColors.ink,
    error: AppColors.negative,
    onError: AppColors.white,
    surface: AppColors.cream,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    outline: AppColors.ink,
    surfaceTint: Colors.transparent,
  );
  const inkBorder = BorderSide(color: AppColors.ink, width: 2.5);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    fontFamily: AppText.bodyFamily,
    textTheme: AppText.textTheme,
    iconTheme: const IconThemeData(color: AppColors.ink),
    // Brutal widgets show a press by sinking into their shadow, not a ripple.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: AppText.label,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: AppText.snack,
      actionTextColor: AppColors.yellow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.ink,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        side: inkBorder,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: AppText.h3,
      contentTextStyle: AppText.body,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: inkBorder,
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.cream,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: AppColors.yellow,
      headerForegroundColor: AppColors.ink,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: inkBorder,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.ink,
      selectionColor: AppColors.yellow,
      selectionHandleColor: AppColors.ink,
    ),
    extensions: const [BrutalTheme.standard],
  );
}
