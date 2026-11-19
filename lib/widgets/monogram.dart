import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';

/// Who was paid, as a list shows them: a shop's first letter, "Z" for
/// Zomato, or a person's initials, "RK" for Ravi Kumar, on a soft colour of
/// its own that stays the same each time.
class Monogram extends StatelessWidget {
  const Monogram({
    super.key,
    required this.name,
    this.person = false,
    this.size = 44,
  });

  final String name;

  /// A person gets two initials; a shop, its first letter.
  final bool person;
  final double size;

  /// Soft steps of Penny's colours, light enough for ink letters.
  static const _colors = [
    Color(0xFFFFD6E3),
    Color(0xFFE6DEFF),
    Color(0xFFD4F0FF),
    Color(0xFFD8F6E0),
    Color(0xFFFFEDB8),
    Color(0xFFFFDDCB),
  ];

  /// "Z" for "Zomato", "RK" for "Ravi Kumar" when [person].
  static String initials(String name, {bool person = false}) {
    final words = [
      for (final word in name.trim().split(RegExp(r'\s+')))
        if (word.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(word[0])) word,
    ];
    if (words.isEmpty) return '?';
    if (!person || words.length == 1) return words.first[0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  static Color colorOf(String name) {
    var hash = 0;
    for (final unit in name.toLowerCase().codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return _colors[hash % _colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final letters = initials(name, person: person);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorOf(name),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.ink, width: 1.5),
        ),
        child: Text(
          letters,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontFamily: AppText.bodyFamily,
            fontWeight: FontWeight.w700,
            fontSize: size * (letters.length > 1 ? 0.34 : 0.4),
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}
