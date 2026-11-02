import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/features/goals/goal_screen.dart';

import '../helpers/app_harness.dart';

void main() {
  Future<void> type(WidgetTester tester, String digits) async {
    for (final digit in digits.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$digit')));
    }
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
  }

  Future<void> openGoals(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Goals'));
    await tester.pumpAndSettle();
  }

  // A goal three months away, made outside the app.
  Future<void> seedGoal(db) => GoalRepository(db).add(
    title: 'Delhi trip',
    targetPaise: 1500000,
    deadline: DateTime.now().add(const Duration(days: 90)),
  );

  testWidgets('a first goal: name it, set it, and put money in', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    await openGoals(tester);
    expect(find.text('Add your first goal'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-first-goal')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('goal-title')),
      'Delhi trip',
    );
    await tester.tap(find.byKey(const ValueKey('goal-target')));
    await tester.pumpAndSettle();
    await type(tester, '15000');
    await tester.tap(find.byKey(const ValueKey('goal-deadline')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-goal')));
    await tester.pumpAndSettle();

    // Straight to the new goal's page.
    expect(find.byType(GoalScreen), findsOneWidget);
    expect(find.textContaining('of ₹15,000 by'), findsOneWidget);
    expect(find.text('Nothing put aside yet.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-money')));
    await tester.pumpAndSettle();
    await type(tester, '3000');
    expect(find.textContaining('₹12,000 to go'), findsOneWidget);
    expect(find.text('+₹3,000'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(find.text('₹3,000 of ₹15,000'), findsOneWidget);
    expect(find.text('₹3,000 put aside this month!'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('reaching a goal makes Penny celebrate', (tester) async {
    final db = await pumpApp(tester, seedDb: seedGoal);
    await openGoals(tester);
    await tester.tap(find.text('Delhi trip'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-money')));
    await tester.pumpAndSettle();
    await type(tester, '15000');
    expect(find.text('Goal achieved! You did it!'), findsOneWidget);
    final today = DateFormat('d MMM').format(DateTime.now());
    expect(find.text('Reached on $today!'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Celebrating'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Calendar'));
    await tester.pumpAndSettle();
    final label = DateFormat('d MMMM').format(DateTime.now());
    expect(find.bySemanticsLabel('$label, today, Celebrating'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('money comes out, and a removed entry can come back', (
    tester,
  ) async {
    final db = await pumpApp(tester, seedDb: seedGoal);
    await openGoals(tester);
    await tester.tap(find.text('Delhi trip'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-money')));
    await tester.pumpAndSettle();
    await type(tester, '3000');

    // Taking out more than is in can't be saved.
    await tester.tap(find.byKey(const ValueKey('take-out')));
    await tester.pumpAndSettle();
    await type(tester, '4000');
    expect(find.text('Take out'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('key-⌫')));
    await tester.tap(find.byKey(const ValueKey('key-⌫')));
    await tester.tap(find.byKey(const ValueKey('key-⌫')));
    await tester.tap(find.byKey(const ValueKey('key-⌫')));
    await type(tester, '500');
    expect(find.text('₹2,500'), findsOneWidget);
    expect(find.text('−₹500'), findsOneWidget);

    await tester.drag(find.text('Taken out'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('−₹500'), findsNothing);
    expect(find.text('₹3,000'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('−₹500'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('deleting a goal asks first', (tester) async {
    final db = await pumpApp(tester, seedDb: seedGoal);
    await openGoals(tester);
    await tester.tap(find.text('Delhi trip'));
    await tester.pumpAndSettle();

    final delete = find.byKey(const ValueKey('delete-goal'));
    await tester.ensureVisible(delete);
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(find.text('Delete this goal?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-goal')));
    await tester.pumpAndSettle();

    expect(find.byType(GoalScreen), findsNothing);
    expect(find.text('Add your first goal'), findsOneWidget);
    await closeApp(tester, db);
  });
}
