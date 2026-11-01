import 'package:flutter/material.dart';
import 'package:penny/widgets/coming_soon.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      title: 'Mood calendar',
      milestone: 4,
      blurb:
          "Every day coloured by Penny's mood, so your spending patterns "
          'show at a glance.',
    );
  }
}
