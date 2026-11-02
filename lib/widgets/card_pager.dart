import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/brutal_theme.dart';

/// Cards side by side to slide between, with dots under them that follow
/// the slide. Every card takes the tallest one's height, so none is cut
/// short mid-slide and nothing under the pager moves.
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

  /// Each card's own height, once laid out.
  late final _heights = List<double?>.filled(widget.pages.length, null);

  /// Where the pager is, in cards: 1.5 is halfway from the second card to
  /// the third.
  double _position = 0;

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

  /// The tallest card's height, once every card has been measured.
  double? get _height {
    if (_heights.contains(null)) return null;
    return _heights.cast<double>().reduce(math.max);
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
  /// room for its shadow.
  Widget _card(int index) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        widget.bleed,
        0,
        widget.bleed,
        context.brutal.shadowOffset.dy,
      ),
      child: widget.pages[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = _height;
    final count = widget.pages.length;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, box) => OverflowBox(
            fit: OverflowBoxFit.deferToChild,
            minWidth: box.maxWidth + widget.bleed * 2,
            maxWidth: box.maxWidth + widget.bleed * 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Every card laid out unseen at its own height, to find the
                // tallest.
                Offstage(
                  child: TickerMode(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < count; i++)
                          _HeightReporter(
                            onHeight: (height) => _measured(i, height),
                            child: _card(i),
                          ),
                      ],
                    ),
                  ),
                ),
                // Until then, the first card at its own height.
                if (height == null)
                  _card(0)
                else
                  SizedBox(
                    height: height,
                    child: PageView(
                      controller: _controller,
                      // Builds the cards either side too, so screen readers
                      // can move to them.
                      allowImplicitScrolling: true,
                      children: [
                        for (var i = 0; i < count; i++)
                          // At least the pager's height. A card that has
                          // just grown overflows for the one frame before
                          // it's measured again, rather than squashing.
                          OverflowBox(
                            minHeight: height,
                            maxHeight: double.infinity,
                            alignment: Alignment.topCenter,
                            child: _card(i),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < count; i++)
              _Dot(
                key: ValueKey('card-dot-$i'),
                label: '${widget.labels[i]}, card ${i + 1} of $count',
                // How much this dot's card is on show: the dots stretch and
                // fill along with the finger while sliding.
                share: (1 - (_position - i).abs()).clamp(0.0, 1.0),
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
    required this.share,
    required this.onTap,
  });

  final String label;

  /// How much this dot's card is on show, from 0 to 1.
  final double share;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: share > 0.5,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Container(
            width: lerpDouble(10, 22, share),
            height: 10,
            decoration: BoxDecoration(
              color: Color.lerp(AppColors.white, AppColors.ink, share),
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
