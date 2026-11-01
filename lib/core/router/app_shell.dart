import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/pill_nav_bar.dart';

/// The frame around the four tabs: the pill nav bar, plus the Add button on
/// Home.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    PillNavItem(icon: Icons.home_rounded, label: 'Home'),
    PillNavItem(icon: Icons.pie_chart_rounded, label: 'Analysis'),
    PillNavItem(icon: Icons.flag_rounded, label: 'Goals'),
    PillNavItem(icon: Icons.calendar_month_rounded, label: 'Calendar'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: index == 0
          ? BrutalButton(
              key: const ValueKey('home-add'),
              label: 'Add',
              icon: Icons.add_rounded,
              onPressed: () => context.push('/add'),
            )
          : null,
      bottomNavigationBar: PillNavBar(
        items: _tabs,
        currentIndex: index,
        // Tapping the tab you're on takes it back to its first screen.
        onSelect: (i) =>
            navigationShell.goBranch(i, initialLocation: i == index),
      ),
    );
  }
}
