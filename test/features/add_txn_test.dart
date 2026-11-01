import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/app.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';

/// Starts the app on a phone-sized screen with an empty in-memory database.
Future<AppDatabase> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  // No idle animations, so the test can settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final db = AppDatabase(
    DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: const PennyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// Home → Add → 2, 5, 0 → Food → ✓.
Future<void> addFood250(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('home-add')));
  await tester.pumpAndSettle();
  for (final key in ['2', '5', '0']) {
    await tester.tap(find.byKey(ValueKey('key-$key')));
    await tester.pump();
  }
  expect(find.text('₹250'), findsOneWidget);
  await tester.tap(find.text('Food'));
  await tester.pumpAndSettle();
  // Picking a category only selects it.
  expect(find.text('Tap the tick to save'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('key-done')));
  await tester.pumpAndSettle();
}

Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await db.close();
}

void main() {
  testWidgets('type 250, tap Food: it shows on Home, and Undo removes it',
      (tester) async {
    final db = await pumpApp(tester);
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);

    await addFood250(tester);

    expect(find.text('Added ₹250 · Food'), findsOneWidget);
    expect(find.text('−₹250'), findsOneWidget); // The new row in Recent.
    expect(find.text('₹250'), findsOneWidget); // Spent this month.

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('−₹250'), findsNothing);
    expect(find.textContaining('Nothing logged yet'), findsOneWidget);
    await closeApp(tester, db);
  });

  testWidgets('the tick waits for an amount and a category', (tester) async {
    final db = await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('home-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    expect(find.text('How much did you spend?'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('key-5')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('key-done')));
    await tester.pumpAndSettle();
    // Still on the Add screen, asking for the category.
    expect(find.text('What was it for?'), findsOneWidget);

    await closeApp(tester, db);
  });

  testWidgets('the undo offer fades by itself and the entry stays',
      (tester) async {
    final db = await pumpApp(tester);
    await addFood250(tester);
    expect(find.text('Added ₹250 · Food'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.text('Added ₹250 · Food'), findsNothing);
    expect(find.text('−₹250'), findsOneWidget);
    await closeApp(tester, db);
  });
}
