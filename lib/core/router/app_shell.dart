import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/router/tab_months.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/pill_nav_bar.dart';

/// The frame around the four tabs: the pill nav bar, with Add beside it.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    PillNavItem(icon: Icons.home_rounded, label: 'Home'),
    PillNavItem(icon: Icons.pie_chart_rounded, label: 'Analysis'),
    PillNavItem(icon: Icons.flag_rounded, label: 'Goals'),
    PillNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar'),
  ];

  /// The month Add starts in: the one Analysis or the Calendar is showing,
  /// when it isn't this month. Null starts it today.
  DateTime? _addMonth(WidgetRef ref, int index) {
    final shown = switch (index) {
      1 => ref.read(analysisMonthProvider),
      3 => ref.read(calendarMonthProvider),
      _ => null,
    };
    return shown == monthStart(DateTime.now()) ? null : shown;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: PillNavBar(
        items: _tabs,
        currentIndex: index,
        // Tapping the tab you're on takes it back to its first screen.
        onSelect: (i) =>
            navigationShell.goBranch(i, initialLocation: i == index),
        // Add is on every tab, in the bar's row, so it never covers the
        // screen. The key is from when it was on Home only.
        trailing: (size) => BrutalIconButton(
          key: const ValueKey('home-add'),
          icon: Icons.add_rounded,
          semanticLabel: 'Add',
          color: AppColors.yellow,
          size: size,
          onPressed: () =>
              context.push(addLocation(month: _addMonth(ref, index))),
        ),
      ),
    );
  }
}
