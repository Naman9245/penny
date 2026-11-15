import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/penny_pose.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/penny_mascot.dart';

/// Saved once the welcome has been seen, so it shows on a first launch only.
const welcomeSeenKey = 'welcome_seen';

/// Three short pages for a first launch: Penny, what stays private, and a
/// way to start. Skippable; Settings can show them again.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _count = 3;

  final _pages = PageController();
  var _page = 0;
  var _leaving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(_page + 1);
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// Leaves for Home, or back to Settings, and on to [then]. With [demo],
  /// the demo data is turned on first.
  Future<void> _leave({String? then, bool demo = false}) async {
    if (_leaving) return;
    _leaving = true;
    await ref.read(sharedPrefsProvider).setBool(welcomeSeenKey, true);
    if (demo) await ref.read(demoModeProvider.notifier).set(true);
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/home');
    }
    if (then != null) router.push(then);
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _count - 1;
    return Scaffold(
      key: const ValueKey('welcome'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  const _Page(
                    penny: PennyMascot(mood: PennyMood.happy, size: 150),
                    stage: AppColors.sky,
                    title: "Hi, I'm Penny!",
                    children: [
                      Text(
                        'I keep an eye on your money with you: what comes in, '
                        'where it goes, and what you can save for.',
                        style: AppText.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const _Page(
                    penny: PennyMascot(pose: PennyPose.analyzing, size: 150),
                    stage: AppColors.mint,
                    title: 'Your money stays yours',
                    children: [
                      _Point(
                        icon: Icons.sms_outlined,
                        text:
                            'Bank SMS are read on your phone. The message '
                            'itself is never saved or sent.',
                      ),
                      _Point(
                        icon: Icons.auto_awesome_outlined,
                        text:
                            "When you ask Penny, her AI sees totals by shop "
                            "and category, never people's names.",
                      ),
                      _Point(
                        icon: Icons.cloud_outlined,
                        text:
                            'Everything lives on this phone. Backing it up '
                            'with Google is your choice.',
                      ),
                    ],
                  ),
                  _Page(
                    penny: const PennyMascot(pose: PennyPose.idea, size: 150),
                    stage: AppColors.lavender,
                    title: 'Where shall we start?',
                    children: [
                      BrutalButton(
                        key: const ValueKey('welcome-add'),
                        label: 'Add a spend',
                        icon: Icons.add_rounded,
                        expand: true,
                        onPressed: () => _leave(then: '/add'),
                      ),
                      const SizedBox(height: 12),
                      BrutalButton(
                        key: const ValueKey('welcome-budget'),
                        label: 'Set a budget',
                        icon: Icons.savings_outlined,
                        color: AppColors.white,
                        expand: true,
                        onPressed: () => _leave(then: '/budget'),
                      ),
                      const SizedBox(height: 12),
                      BrutalButton(
                        key: const ValueKey('welcome-demo'),
                        label: 'Try demo data',
                        icon: Icons.science_outlined,
                        color: AppColors.white,
                        expand: true,
                        onPressed: () => _leave(demo: true),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('welcome-skip'),
                        onPressed: _leave,
                        child: Text(
                          last ? 'Just look around' : 'Skip',
                          style: AppText.bodyStrong,
                        ),
                      ),
                    ),
                  ),
                  _Dots(count: _count, page: _page),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: last
                          ? null
                          : BrutalButton(
                              key: const ValueKey('welcome-next'),
                              label: 'Next',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _next,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One page: Penny, a title, and what goes under it, centred.
class _Page extends StatelessWidget {
  const _Page({
    required this.penny,
    required this.stage,
    required this.title,
    required this.children,
  });

  final Widget penny;

  /// The colour of the round stage Penny stands on.
  final Color stage;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: stage,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.ink,
                      width: kBorderWidth,
                    ),
                    boxShadow: const [
                      BoxShadow(color: AppColors.ink, offset: kCardShadow),
                    ],
                  ),
                  child: penny,
                ),
              ),
              const SizedBox(height: 24),
              Text(title, style: AppText.h1, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// A promise about privacy, with its icon.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 2),
            ),
            child: Icon(icon, size: 20, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body)),
        ],
      ),
    );
  }
}

/// Which page is showing: the current one a pill, the rest rings.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${page + 1} of $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == page ? 22 : 10,
              height: 10,
              decoration: BoxDecoration(
                color: i == page ? AppColors.ink : AppColors.white,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
            ),
        ],
      ),
    );
  }
}
