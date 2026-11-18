import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/router/app_shell.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/autopays/autopays_screen.dart';
import 'package:penny/features/add_txn/add_txn_controller.dart';
import 'package:penny/features/add_txn/add_txn_screen.dart';
import 'package:penny/features/analysis/analysis_screen.dart';
import 'package:penny/features/budget/budget_screen.dart';
import 'package:penny/features/calendar/calendar_screen.dart';
import 'package:penny/features/chat/chat_screen.dart';
import 'package:penny/features/goals/goal_editor_screen.dart';
import 'package:penny/features/goals/goal_screen.dart';
import 'package:penny/features/goals/goals_screen.dart';
import 'package:penny/features/home/home_screen.dart';
import 'package:penny/features/import/import_screen.dart';
import 'package:penny/features/needs/needs_screen.dart';
import 'package:penny/features/report/report_screen.dart';
import 'package:penny/features/transactions/txn_list_screen.dart';
import 'package:penny/features/welcome/welcome_screen.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/sms_parser.dart';

/// The app's routes. A first launch opens on the welcome.
final routerProvider = Provider<GoRouter>((ref) {
  final welcomed =
      ref.read(sharedPrefsProvider).getBool(welcomeSeenKey) ?? false;
  final router = GoRouter(
    initialLocation: welcomed ? '/home' : '/welcome',
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
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/add',
        // Optional ?type=credit, and ?month=2026-10 to start on its 1st.
        builder: (context, state) => AddTxnView(
          args: AddTxnArgs.create(
            state.uri.queryParameters['type'] == 'credit'
                ? TxnType.credit
                : TxnType.debit,
            day: _monthFromQuery(state.uri.queryParameters['month']),
          ),
        ),
      ),
      // A shared or pasted SMS, already read and masked. It travels as an
      // in-memory object, never as text in the location.
      GoRoute(
        path: '/import',
        builder: (context, state) => ImportScreen(
          sms: switch (state.extra) {
            final SmsParse sms => sms,
            _ => null,
          },
        ),
      ),
      // A payment read from a notification, to check before it's added.
      GoRoute(
        path: '/capture',
        builder: (context, state) => switch (state.extra) {
          final PendingCapture capture => AddTxnView(
            args: AddTxnArgs.fromCapture(capture),
          ),
          _ => const ImportScreen(sms: null),
        },
      ),
      GoRoute(
        path: '/txns',
        // Optional ?month=2026-11&category=food, from an Analysis card.
        builder: (context, state) => TxnListScreen(
          initialMonth: _monthFromQuery(state.uri.queryParameters['month']),
          categoryId: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/txns/:id',
        builder: (context, state) =>
            AddTxnScreen(editId: state.pathParameters['id']),
      ),
      GoRoute(path: '/needs', builder: (context, state) => const NeedsScreen()),
      GoRoute(
        path: '/autopays',
        builder: (context, state) => const AutopaysScreen(),
      ),
      GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      // Before /goals/:id, which would take "new" for an id.
      GoRoute(
        path: '/goals/new',
        builder: (context, state) => const GoalEditorScreen(),
      ),
      GoRoute(
        path: '/goals/:id/edit',
        builder: (context, state) =>
            GoalEditorScreen(goalId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/goals/:id',
        builder: (context, state) =>
            GoalScreen(goalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/report',
        // ?month=2026-10, from the Analysis tab; this month when missing.
        builder: (context, state) => ReportScreen(
          month:
              _monthFromQuery(state.uri.queryParameters['month']) ??
              monthStart(DateTime.now()),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// The location of Add, starting on the 1st of [month] when there is one.
String addLocation({DateTime? month}) => Uri(
  path: '/add',
  queryParameters: month == null ? null : {'month': monthKey(month)},
).toString();

/// The location of [month]'s entries, optionally just one category's.
String txnsLocation(DateTime month, {String? categoryId}) {
  final params = {'month': monthKey(month), 'category': ?categoryId};
  return Uri(path: '/txns', queryParameters: params).toString();
}

/// The location of Penny's report for [month].
String reportLocation(DateTime month) => Uri(
  path: '/report',
  queryParameters: {'month': monthKey(month)},
).toString();

/// "2026-11" → 1 November 2026; anything else → null.
DateTime? _monthFromQuery(String? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value ?? '');
  if (match == null) return null;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(1)!), month);
}
