import 'package:flutter/widgets.dart';

/// Fades scrolling content out at its top and bottom edges, so a card
/// passing under a fixed header or the keypad melts away instead of being
/// sliced through its thick border.
class EdgeFade extends StatelessWidget {
  const EdgeFade({super.key, required this.child, this.size = 20});

  final Widget child;

  /// How far, in logical pixels, each fade reaches in.
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        if (!height.isFinite || height <= size * 2) return child;
        final edge = size / height;
        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x00000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0, edge, 1 - edge, 1],
          ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}
