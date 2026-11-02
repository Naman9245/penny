import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';

/// Cards side by side to slide between, with dots under them saying which
/// one shows. The pager is as tall as the card on show, blending between
/// two while sliding, so every card keeps its own height.
class CardPager extends StatefulWidget {
  const CardPager({
    super.key,
    required this.pages,
    required this.labels,
    this.bleed = 16,
  }) : assert(pages.length == labels.length);

  final List<Widget> pages;

  /// What each card is, for its dot and screen readers.
  final List<String> labels;

  /// How far the pager reaches into its parent's side padding, so a card
  /// slides off the edge of the screen instead of vanishing at the margin.
  /// Each card is inset by the same amount, so it lines up as before.
  final double bleed;

  @override
  State<CardPager> createState() => _CardPagerState();
}

class _CardPagerState extends State<CardPager> {
  final _controller = PageController();

  /// Each card's height, once laid out.
  late final _heights = List<double?>.filled(widget.pages.length, null);

  /// Where the pager is, in cards: 1.5 is halfway from the second card to
  /// the third.
  double _position = 0;

  /// The height the pager last had.
  double? _shown;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final page = _controller.page;
      if (page != null && page != _position) setState(() => _position = page);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measured(int index, double height) {
    if (mounted && _heights[index] != height) {
      setState(() => _heights[index] = height);
    }
  }

  /// The height of the card on show, or a blend of two while sliding. A
  /// card not measured yet, like one a dot jumps to, keeps the height the
  /// pager had until it is.
  double _height(double first) {
    final last = _heights.length - 1;
    final from = _position.floor().clamp(0, last);
    final to = _position.ceil().clamp(0, last);
    final height = _heights[from] ?? _shown ?? first;
    return lerpDouble(height, _heights[to] ?? height, _position - from)!;
  }

  void _show(int index) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Card [index], inset to line up with the rest of the page and to leave
  /// room for its shadow, reporting its height.
  Widget _card(int index) {
    return _HeightReporter(
      onHeight: (height) => _measured(index, height),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          widget.bleed,
          0,
          widget.bleed,
          context.brutal.shadowOffset.dy,
        ),
        child: widget.pages[index],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _heights[0];
    // The first card is laid out on its own once, to learn how tall the
    // pager should be.
    final cards = first == null
        ? _card(0)
        : SizedBox(
            height: _shown = _height(first),
            child: PageView(
              controller: _controller,
              // Builds the cards either side too, so their heights are
              // known before they slide in.
              allowImplicitScrolling: true,
              children: [
                for (var i = 0; i < widget.pages.length; i++)
                  OverflowBox(
                    minHeight: 0,
                    maxHeight: double.infinity,
                    alignment: Alignment.topCenter,
                    child: _card(i),
                  ),
              ],
            ),
          );
    final current = _position.round();
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) => OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minWidth: box.maxWidth + widget.bleed * 2,
            maxWidth: box.maxWidth + widget.bleed * 2,
            child: cards,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.pages.length; i++)
              _Dot(
                key: ValueKey('card-dot-$i'),
                label:
                    '${widget.labels[i]}, card ${i + 1} of '
                    '${widget.pages.length}',
                current: i == current,
                onTap: () => _show(i),
              ),
          ],
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    super.key,
    required this.label,
    required this.current,
    required this.onTap,
  });

  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: current,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: current ? 22 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: current ? AppColors.ink : AppColors.white,
              borderRadius: BorderRadius.circular(kPillRadius),
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells [onHeight] its child's height after each layout that changes it.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, super.child});

  final ValueChanged<double> onHeight;

  @override
  _RenderHeightReporter createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _reported) return;
    _reported = height;
    // After the frame: the pager rebuilds to fit, which can't happen
    // during layout.
    WidgetsBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
