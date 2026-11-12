import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/theme/app_theme.dart';
import 'package:penny/data/budget_repository.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/chat_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/demo_data.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/data/upcoming_repository.dart';
import 'package:penny/features/lock/lock_gate.dart';
import 'package:penny/features/welcome/welcome_screen.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/fake_ai.dart';
import '../test/helpers/fixed_today.dart';

// Draws every main screen on the demo data, on a phone-sized screen with
// Penny's real fonts, to look the app over without a phone:
//
//   flutter test tool/screenshots_test.dart
//
// The pictures land in build/screenshots/.

const _out = 'build/screenshots';

final _app = GlobalKey();

void main() {
  testWidgets('render every screen', (tester) async {
    await _loadFonts();
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await tester.runAsync(() async {
      await fillDemoData(db, DateTime.now());
      final chat = ChatRepository(db);
      await chat.add(ChatRole.user, 'Where did my money go this month?');
      await chat.add(
        ChatRole.penny,
        'Mostly rent, about ₹8,500. Food came next at about ₹2,300, much of '
        'it Zomato. Cooking two dinners a week could save you around ₹600.',
      );
    });
    await _pump(tester, db);
    final router = _router(tester);

    await _shot(tester, '01_home');
    await _scroll(tester, -560);
    await _shot(tester, '02_home_more');
    await _scroll(tester, -900);
    await _shot(tester, '03_home_recent');

    router.go('/analysis');
    await _shot(tester, '04_analysis');
    await _scroll(tester, -700);
    await _shot(tester, '05_analysis_more');
    await _scroll(tester, -1200);
    await _shot(tester, '06_analysis_end');

    router.go('/goals');
    await _shot(tester, '07_goals');
    await tester.tap(find.byWidgetPredicate(_isGoalCard).first);
    await _shot(tester, '08_goal');
    router.pop();

    router.go('/calendar');
    await _shot(tester, '09_calendar');
    await _scroll(tester, -600);
    await _shot(tester, '10_calendar_more');
    await _scroll(tester, 600);
    await tester.tap(find.byKey(ValueKey('day-${DateTime.now().day}')));
    await _shot(tester, '11_day');
    // Above the sheet.
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    router.go('/home');
    await tester.pumpAndSettle();
    router.push('/add');
    await _shot(tester, '12_add');
    for (final key in ['2', '4', '0']) {
      await tester.tap(find.byKey(ValueKey('key-$key')));
    }
    await tester.tap(find.bySemanticsLabel('Food').first);
    await _shot(tester, '13_add_filled');
    router.pop();

    router.push('/txns');
    await _shot(tester, '14_transactions');
    router.pop();

    router.push('/budget');
    await _shot(tester, '15_budget');
    router.pop();

    router.push('/needs');
    await _shot(tester, '16_needs');
    router.pop();

    router.push('/report');
    await _shot(tester, '17_report');
    await _scroll(tester, -900);
    await _shot(tester, '18_report_more');
    router.pop();

    router.push('/chat');
    await _shot(tester, '19_chat');
    router.pop();

    await tester.pumpAndSettle();
    // Home is still scrolled down to Recent.
    await _scroll(tester, 3000);
    await tester.tap(find.bySemanticsLabel('Settings'));
    await _shot(tester, '20_settings');
    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();

    router.push('/welcome');
    await _shot(tester, '21_welcome');

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });

  testWidgets('render Home with things to look at', (tester) async {
    await _loadFonts();
    final now = DateTime.now();
    // The 3rd, when last month's fixed bills come up.
    final today = DateTime(now.year, now.month, 3);
    final db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await tester.runAsync(() async {
      final txns = TxnRepository(db);
      Future<void> spend(
        int rupees,
        String category,
        DateTime at,
        String? where,
      ) => txns
          .add(
            amountPaise: rupees * 100,
            type: TxnType.debit,
            categoryId: category,
            occurredAt: at,
            merchant: where,
          )
          .then((_) {});
      final lastMonth = DateTime(now.year, now.month - 1, 2, 10);
      await spend(8500, 'rent', lastMonth, 'Sunrise PG');
      await spend(199, 'subscriptions', lastMonth, 'Netflix');
      await spend(299, 'bills', lastMonth, 'Airtel');
      await txns.add(
        amountPaise: 1500000,
        type: TxnType.credit,
        categoryId: 'pocket_money',
        occurredAt: DateTime(now.year, now.month, 1, 9),
      );
      await spend(120, 'food', DateTime(now.year, now.month, 2, 13), 'Swiggy');
      await spend(60, 'travel', today.add(const Duration(hours: 9)), 'Metro');
      await BudgetRepository(db).setAmount('food', 600000);
      await BudgetRepository(db).setAmount('travel', 200000);
      final captures = CaptureRepository(db);
      final at = today.add(const Duration(hours: 10));
      await captures.hold(
        readCapture((
          app: 'sms',
          title: 'AX-HDFCBK',
          text:
              'Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref '
              '630512345678.',
          at: at,
        ))!,
        app: 'sms',
        at: at,
      );
      await UpcomingRepository(db).keep((
        amountPaise: 149900,
        dueOn: today.add(const Duration(days: 2)),
        payee: 'Netflix',
        categoryId: 'subscriptions',
        dedupeKey: 'netflix-due',
      ));
    });
    await _pump(tester, db, overrides: [todayIs(today)]);
    await _shot(tester, '22_home_to_check');
    await _scroll(tester, -560);
    await _shot(tester, '23_home_to_check_more');

    await tester.pumpWidget(const SizedBox());
    await db.close();
  });
}

bool _isGoalCard(Widget widget) =>
    widget.key is ValueKey<String> &&
    RegExp(r"^goal-[0-9a-f-]{36}$")
        .hasMatch((widget.key! as ValueKey<String>).value);

/// The app on a phone-sized screen, as the tests start it, inside a
/// boundary to take pictures of.
///
/// It's PennyApp's own MaterialApp, without the listeners that read
/// payments, and with an emoji font to fall back on: the test engine has
/// no fonts of its own to find one in, as a phone does.
Future<void> _pump(
  WidgetTester tester,
  AppDatabase db, {
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  // Penny holds still, so every picture is the same each time.
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

  // A tool, not a test, so the analyzer doesn't know it may.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({welcomeSeenKey: true});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    RepaintBoundary(
      key: _app,
      child: ProviderScope(
        overrides: [
          ...overrides,
          appDatabaseProvider.overrideWithValue(db),
          sharedPrefsProvider.overrideWithValue(prefs),
          aiClientProvider.overrideWithValue(FakeAiClient(isSetUp: false)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final theme = buildAppTheme();
            return MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamilyFallback: const ['NotoColorEmoji'],
                ),
              ),
              routerConfig: ref.watch(routerProvider),
              builder: (context, child) => LockGate(child: child!),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)))
        .read(routerProvider);

/// Drags the topmost list by [dy].
Future<void> _scroll(WidgetTester tester, double dy) async {
  await tester.drag(find.byType(Scrollable).hitTestable().first, Offset(0, dy));
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary =
      _app.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(
      pixelRatio: tester.view.devicePixelRatio,
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File('$_out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

/// Penny's own fonts, and the icon and emoji fonts the phone would have.
/// Tests draw with a stand-in font otherwise.
Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(
        Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
      );
    }
    await loader.load();
  }

  await family('Baloo2', [
    for (final weight in ['SemiBold', 'Bold', 'ExtraBold'])
      'assets/fonts/Baloo2-$weight.ttf',
  ]);
  await family('DMSans', [
    for (final weight in ['Regular', 'Medium', 'Bold'])
      'assets/fonts/DMSans-$weight.ttf',
  ]);
  // flutter_tester sits in bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  await family('MaterialIcons', [
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ]);
  const emoji = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
  if (File(emoji).existsSync()) await family('NotoColorEmoji', [emoji]);
}
