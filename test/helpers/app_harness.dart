import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/app.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/services/penny_ai.dart';

import 'fake_ai.dart';

/// Starts the app on a phone-sized screen with an in-memory database, empty
/// apart from what [seed] and [seedDb] add. Penny's server is [ai], or a
/// fake that isn't set up.
///
/// Seed here rather than after start-up: writing from outside the test's
/// fake clock while the app's live queries are open deadlocks drift.
Future<AppDatabase> pumpApp(
  WidgetTester tester, {
  Future<void> Function(TxnRepository repo)? seed,
  Future<void> Function(AppDatabase db)? seedDb,
  AiClient? ai,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  // No idle animations, so the test can settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  if (seed != null) await tester.runAsync(() => seed(TxnRepository(db)));
  if (seedDb != null) await tester.runAsync(() => seedDb(db));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        aiClientProvider.overrideWithValue(ai ?? FakeAiClient(isSetUp: false)),
      ],
      child: const PennyApp(),
    ),
  );
  await tester.pumpAndSettle();
  return db;
}

/// The app's router, for opening routes the way a share would.
GoRouter routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PennyApp)))
        .read(routerProvider);

Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await db.close();
}
