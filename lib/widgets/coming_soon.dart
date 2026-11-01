import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/penny_mascot.dart';

/// Stands in for a tab whose milestone hasn't landed yet.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.title,
    required this.milestone,
    required this.blurb,
  });

  final String title;
  final int milestone;
  final String blurb;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(title, style: AppText.h1),
          const SizedBox(height: 20),
          BrutalCard(
            color: AppColors.lavender,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                const PennyMascot(size: 120),
                const SizedBox(height: 16),
                Text(
                  'Arrives in Milestone $milestone',
                  style: AppText.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(blurb, style: AppText.body, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
