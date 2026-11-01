import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/router/app_shell.dart';
import 'package:penny/features/add_txn/add_txn_screen.dart';
import 'package:penny/features/analysis/analysis_screen.dart';
import 'package:penny/features/calendar/calendar_screen.dart';
import 'package:penny/features/goals/goals_screen.dart';
import 'package:penny/features/home/home_screen.dart';
import 'package:penny/features/transactions/txn_list_screen.dart';
import 'package:penny/models/txn_enums.dart';

/// A provider, so Milestone 5 can add sign-in redirects that watch auth state.
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analysis',
                builder: (context, state) => const AnalysisScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/goals',
                builder: (context, state) => const GoalsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
        ],
      ),
      // Full-screen routes that cover the tab bar.
      GoRoute(
        path: '/add',
        builder: (context, state) => AddTxnScreen(
          initialType: state.uri.queryParameters['type'] == 'credit'
              ? TxnType.credit
              : TxnType.debit,
        ),
      ),
      GoRoute(
        path: '/txns',
        builder: (context, state) => const TxnListScreen(),
      ),
      GoRoute(
        path: '/txns/:id',
        builder: (context, state) =>
            AddTxnScreen(editId: state.pathParameters['id']),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
