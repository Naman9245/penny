import 'package:flutter/material.dart';
import 'package:penny/widgets/coming_soon.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoon(
      title: 'Analysis',
      milestone: 2,
      blurb: 'Where your money comes from and where it goes, with charts and '
          'a card for every category.',
    );
  }
}
