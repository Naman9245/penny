import 'package:flutter/material.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/services/sms_parser.dart';
import 'package:penny/widgets/brutal_card.dart';

/// The SMS as Penny read it: sensitive numbers already blanked on the phone,
/// and what it took for the entry highlighted.
class SmsCard extends StatelessWidget {
  const SmsCard({super.key, required this.preview});

  final SmsPreview preview;

  static const _marks = {
    SpanKind.amount: AppColors.yellow,
    SpanKind.payee: AppColors.sky,
    SpanKind.date: AppColors.mint,
  };

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sms_outlined, size: 18, color: AppColors.ink),
              SizedBox(width: 6),
              Text('From your SMS', style: AppText.label),
            ],
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(children: _pieces()),
            style: AppText.small.copyWith(color: AppColors.ink, height: 1.45),
          ),
          const SizedBox(height: 10),
          const Text(
            'Highlighted is what Penny read. Account, card and reference '
            'numbers are hidden, and the message itself is never saved.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _pieces() {
    final text = preview.text;
    final marks = [
      for (final span in preview.spans)
        if (_marks.containsKey(span.kind)) span,
    ]..sort((a, b) => a.start.compareTo(b.start));

    final pieces = <InlineSpan>[];
    var at = 0;
    for (final mark in marks) {
      if (mark.start < at) continue; // Overlaps the mark before it.
      if (mark.start > at) pieces.add(TextSpan(text: text.substring(at, mark.start)));
      pieces.add(
        TextSpan(
          text: text.substring(mark.start, mark.end),
          style: TextStyle(
            backgroundColor: _marks[mark.kind],
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      at = mark.end;
    }
    if (at < text.length) pieces.add(TextSpan(text: text.substring(at)));
    return pieces;
  }
}
