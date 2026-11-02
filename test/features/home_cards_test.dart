import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/features/goals/goal_editor_screen.dart';
import 'package:penny/features/goals/goal_screen.dart';
import 'package:penny/services/budget_math.dart';

import '../helpers/app_harness.dart';

void main() {
  // One goal going, and headphones paid off today.
  Future<void> seedGoals(AppDatabase db) async {
    final goals = GoalRepository(db);
    await goals.add(
      title: 'Delhi trip',
      targetPaise: 1500000,
      deadline: DateTime.now().add(const Duration(days: 90)),
    );
    final headphones = await goals.add(
      title: 'Headphones',
      targetPaise: 250000,
      deadline: DateTime.now().add(const Duration(days: 20)),
    );
    await goals.deposit(headphones, 250000);
  }

  final cards = find.byKey(const ValueKey('home-cards'));

  testWidgets("Penny names the goal she's celebrating, apart from the budget", (
    tester,
  ) async {
    final db = await pumpApp(
      tester,
      seedDb: (db) async {
        await seedGoals(db);
        await BudgetRepository(db).setAmount('food', 500000);
      },
    );

    expect(find.text('Headphones reached! You did it!'), findsOneWidget);
    expect(find.text('Goal achieved! You did it!'), findsNothing);
    final now = DateTime.now();
    final left = daysLeftLabel(
      DateTime(now.year, now.month + 1, 0).day - now.day,
    );
    final box = find.byKey(const ValueKey('budget-box'));
    expect(
      find.descendant(of: box, matching: find.text('Everyday budget · $left')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: box, matching: find.text('₹0 of ₹5,000')),
      findsOneWidget,
    );
    await closeApp(tester, db);
  });

  testWidgets('slide the card for goals to reach, then goals reached', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: seedGoals);
    expect(find.text('Goals to reach'), findsNothing);

    await tester.drag(cards, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Goals to reach'), findsOneWidget);
    expect(find.text('Delhi trip'), findsOneWidget);
    expect(find.text('₹0 of ₹15,000'), findsOneWidget);
    expect(find.text('Headphones'), findsNothing);

    await tester.drag(cards, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Goals reached'), findsOneWidget);
    expect(find.text('Headphones'), findsOneWidget);
    final today = DateFormat('d MMM').format(DateTime.now());
    expect(find.text('Reached on $today!'), findsOneWidget);

    await tester.tap(find.text('Headphones'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalScreen), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('every card is as tall as the tallest; dots follow the finger', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: seedGoals);
    final spent = find.textContaining('Spent in');
    final below = tester.getTopLeft(spent);
    final tall = tester.getSize(find.byKey(const ValueKey('penny-card')));
    double dot(int i) =>
        tester.getSize(find.byKey(ValueKey('card-dot-$i'))).width;
    final (still, current) = (dot(1), dot(0));

    // Halfway to the next card: nothing below moves, and the two dots
    // share the stretch.
    final gesture = await tester.startGesture(tester.getCenter(cards));
    await gesture.moveBy(const Offset(-20, 0));
    await gesture.moveBy(const Offset(-180, 0));
    await tester.pump();
    expect(tester.getTopLeft(spent), below);
    expect(dot(0), inExclusiveRange(still, current));
    expect(dot(1), inExclusiveRange(still, current));
    // On past halfway, so it lands on the next card.
    await gesture.moveBy(const Offset(-180, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byKey(const ValueKey('goals-to-reach'))), tall);
    expect(tester.getTopLeft(spent), below);
    await tester.drag(cards, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('goals-reached'))), tall);
    expect(tester.getTopLeft(spent), below);
    await closeApp(tester, db);
  });

  testWidgets('a dot slides to its card, and All goals opens Goals', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: seedGoals);

    await tester.tap(find.byKey(const ValueKey('card-dot-2')));
    await tester.pumpAndSettle();
    expect(find.text('Goals reached'), findsOneWidget);

    await tester.tap(find.text('All goals'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('goals-cheer')), findsOneWidget);
    expect(find.text('Headphones reached! You did it!'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('with no goals, the card offers to add one', (tester) async {
    final db = await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('card-dot-1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No goals yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('card-dot-2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('None yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('card-dot-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-add-goal')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalEditorScreen), findsOneWidget);
    await closeApp(tester, db);
  });
}
