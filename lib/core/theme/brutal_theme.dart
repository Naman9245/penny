import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';

/// Radius that turns any box into a pill.
const double kPillRadius = 999;

/// Neobrutalism tokens: thick ink borders and hard shadows with no blur.
@immutable
class BrutalTheme extends ThemeExtension<BrutalTheme> {
  const BrutalTheme({
    required this.borderWidth,
    required this.shadowOffset,
    required this.cardRadius,
    required this.inputRadius,
  });

  static const standard = BrutalTheme(
    borderWidth: 2.5,
    shadowOffset: Offset(4, 4),
    cardRadius: 24,
    inputRadius: 16,
  );

  final double borderWidth;
  final Offset shadowOffset;
  final double cardRadius;
  final double inputRadius;

  @override
  BrutalTheme copyWith({
    double? borderWidth,
    Offset? shadowOffset,
    double? cardRadius,
    double? inputRadius,
  }) {
    return BrutalTheme(
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      cardRadius: cardRadius ?? this.cardRadius,
      inputRadius: inputRadius ?? this.inputRadius,
    );
  }

  // The tokens are constants, so a theme change simply swaps them.
  @override
  BrutalTheme lerp(BrutalTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension BrutalThemeContext on BuildContext {
  BrutalTheme get brutal =>
      Theme.of(this).extension<BrutalTheme>() ?? BrutalTheme.standard;
}

/// The decoration every brutal surface shares: fill, ink border, hard shadow.
///
/// There is always exactly one shadow, so a press can animate its offset to
/// zero instead of making it pop out of existence.
BoxDecoration brutalDecoration({
  required Color color,
  required double radius,
  double borderWidth = 2.5,
  Offset shadow = Offset.zero,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.ink, width: borderWidth),
    boxShadow: [BoxShadow(color: AppColors.ink, offset: shadow)],
  );
}
