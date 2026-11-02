import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';

/// A moving bar while Penny thinks, still when the system asks for less
/// motion.
class WaitingBar extends StatelessWidget {
  const WaitingBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(kPillRadius),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kPillRadius),
            child: MediaQuery.disableAnimationsOf(context)
                ? const SizedBox.expand()
                : const LinearProgressIndicator(
                    minHeight: 10,
                    color: AppColors.ink,
                    backgroundColor: AppColors.white,
                    semanticsLabel: 'Penny is thinking',
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This can take up to half a minute.',
          style: AppText.small.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}
