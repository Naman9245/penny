import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/features/welcome/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

void main() {
  final welcome = find.byKey(const ValueKey('welcome'));
  final home = find.byKey(const ValueKey('home-cards'));

  Future<bool?> welcomed() async =>
      (await SharedPreferences.getInstance()).getBool(welcomeSeenKey);

  testWidgets('a first launch opens the welcome; skip goes Home, for good', (
    tester,
  ) async {
    final db = await pumpApp(tester, prefs: {welcomeSeenKey: false});
    expect(welcome, findsOneWidget);
    expect(find.text("Hi, I'm Penny!"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(welcome, findsNothing);
    expect(home, findsOneWidget);
    expect(await welcomed(), isTrue);
    await closeApp(tester, db);
  });

  testWidgets('next, next, then straight to adding a spend', (tester) async {
    final db = await pumpApp(tester, prefs: {welcomeSeenKey: false});
    await tester.tap(find.byKey(const ValueKey('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Your money stays yours'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-next')));
    await tester.pumpAndSettle();
    expect(find.text('Where shall we start?'), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-next')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('welcome-add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('key-done')), findsOneWidget);
    // Back from Add lands on Home.
    routerOf(tester).pop();
    await tester.pumpAndSettle();
    expect(home, findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('Settings shows the welcome again, then goes back to Home', (
    tester,
  ) async {
    final db = await pumpApp(tester);
    expect(welcome, findsNothing);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    final again = find.byKey(const ValueKey('show-welcome'));
    await tester.ensureVisible(again);
    await tester.pumpAndSettle();
    await tester.tap(again);
    await tester.pumpAndSettle();
    expect(welcome, findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pumpAndSettle();
    expect(welcome, findsNothing);
    expect(home, findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    await closeApp(tester, db);
  });
}
