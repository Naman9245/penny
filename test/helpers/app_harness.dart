import 'dart:io';

import 'package:drift/drift.dart' show DatabaseConnection, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/app.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/features/welcome/welcome_screen.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Map<String, Object> prefs = const {},
}) async {
  final db = AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
  if (seed != null) await tester.runAsync(() => seed(TxnRepository(db)));
  if (seedDb != null) await tester.runAsync(() => seedDb(db));
  await pumpPenny(
    tester,
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    prefs: prefs,
    ai: ai,
  );
  return db;
}

/// Starts the app on a phone-sized screen with [overrides], the phone's
/// saved settings as [prefs], and Penny's server as [ai] or a fake that
/// isn't set up. The welcome counts as seen unless [prefs] says otherwise.
Future<void> pumpPenny(
  WidgetTester tester, {
  List<Override> overrides = const [],
  Map<String, Object> prefs = const {},
  AiClient? ai,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  // No idle animations, so the test can settle.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  SharedPreferences.setMockInitialValues({welcomeSeenKey: true, ...prefs});
  final sharedPrefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        sharedPrefsProvider.overrideWithValue(sharedPrefs),
        aiClientProvider.overrideWithValue(ai ?? FakeAiClient(isSetUp: false)),
      ],
      child: const PennyApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls Home down to Recent, which starts below Penny's cards on a
/// phone-sized screen.
Future<void> scrollToRecent(WidgetTester tester) => _dragHome(tester, -400);

/// Scrolls Home back up to the top.
Future<void> scrollToTop(WidgetTester tester) => _dragHome(tester, 400);

Future<void> _dragHome(WidgetTester tester, double dy) async {
  // Home's own list comes before the cards' pager inside it.
  await tester.drag(find.byType(Scrollable).first, Offset(0, dy));
  await tester.pumpAndSettle();
}

/// The app's router, for opening routes the way a share would.
GoRouter routerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(PennyApp)))
        .read(routerProvider);

Future<void> closeApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await db.close();
}

/// Databases in a temporary folder, opened by name like the app's own, so
/// one closed and opened again still has what was in it.
class TempDatabases {
  TempDatabases() {
    // Two open at once is the point here, each with its own connection.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final _dir = Directory.systemTemp.createTempSync('penny_test_');

  /// Every name opened, in order.
  final opened = <String>[];

  AppDatabase open(String name) {
    opened.add(name);
    return AppDatabase(
      DatabaseConnection(
        NativeDatabase(File('${_dir.path}/$name.sqlite')),
        closeStreamsSynchronously: true,
      ),
    );
  }

  /// Deletes the folder. Call once every database in it is closed.
  void delete() {
    try {
      _dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Windows can still hold a file that has only just closed. It's in the
      // system's temporary folder, which gets cleaned anyway.
    }
  }
}
