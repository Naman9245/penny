import 'package:flutter/material.dart';
import 'package:penny/widgets/coming_soon.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      title: 'Goals',
      milestone: 4,
      blurb: 'Save for things like a Delhi trip. Penny works out what to put '
          'aside each week from your real spending.',
    );
  }
}
