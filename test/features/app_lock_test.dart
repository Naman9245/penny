import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/app_lock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

/// A phone's fingerprint check, faked: whether there's a screen lock, and
/// each check waits for the test to say how it went.
class FakeAuthenticator implements Authenticator {
  FakeAuthenticator({this.hasScreenLock = true});

  final bool hasScreenLock;
  final asked = <String>[];
  Completer<bool>? _waiting;

  @override
  Future<bool> canCheck() async => hasScreenLock;

  @override
  Future<bool> check(String reason) {
    asked.add(reason);
    return (_waiting = Completer<bool>()).future;
  }

  /// Answers the check waiting, as the owner or not.
  void answer(bool owner) => _waiting?.complete(owner);
}

void main() {
  final lockScreen = find.byKey(const ValueKey('lock-screen'));

  testWidgets('off, Penny opens straight away', (tester) async {
    final auth = FakeAuthenticator();
    final db = await pumpApp(
      tester,
      overrides: [authenticatorProvider.overrideWithValue(auth)],
    );
    expect(lockScreen, findsNothing);
    expect(auth.asked, isEmpty);
    await closeApp(tester, db);
  });

  testWidgets('on, she opens locked until it is you', (tester) async {
    final auth = FakeAuthenticator();
    final db = await pumpApp(
      tester,
      prefs: {AppLock.key: true},
      overrides: [authenticatorProvider.overrideWithValue(auth)],
    );
    expect(lockScreen, findsOneWidget);
    expect(find.text('Penny is locked'), findsOneWidget);
    expect(auth.asked, ['Unlock Penny']);

    // Not you: still locked, and Unlock asks again.
    auth.answer(false);
    await tester.pumpAndSettle();
    expect(lockScreen, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unlock')));
    await tester.pumpAndSettle();
    auth.answer(true);
    await tester.pumpAndSettle();
    expect(lockScreen, findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('turning it on needs a screen lock, and you', (tester) async {
    final auth = FakeAuthenticator(hasScreenLock: false);
    final db = await pumpApp(
      tester,
      overrides: [authenticatorProvider.overrideWithValue(auth)],
    );
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tapInView(tester, find.byKey(const ValueKey('app-lock')));
    expect(find.byKey(const ValueKey('app-lock-problem')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-lock-on')), findsNothing);
    await closeApp(tester, db);
  });

  testWidgets('turned on once it checks out, without locking there and then', (
    tester,
  ) async {
    final auth = FakeAuthenticator();
    final db = await pumpApp(
      tester,
      overrides: [authenticatorProvider.overrideWithValue(auth)],
    );
    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pumpAndSettle();
    await tapInView(tester, find.byKey(const ValueKey('app-lock')));
    expect(auth.asked, ['Turn on the lock']);
    auth.answer(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-lock-on')), findsOneWidget);
    expect(lockScreen, findsNothing);
    await closeApp(tester, db);
  });

  test('she locks again after a minute away, not sooner', () async {
    SharedPreferences.setMockInitialValues({AppLock.key: true});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        authenticatorProvider.overrideWithValue(FakeAuthenticator()),
      ],
    );
    addTearDown(container.dispose);
    final locked = container.read(lockedProvider.notifier);
    // Opened locked; say it was unlocked.
    expect(container.read(lockedProvider), isTrue);
    locked.state = false;

    final at = DateTime(2026, 11, 11, 10);
    locked
      ..away(at)
      ..back(at.add(const Duration(seconds: 50)));
    expect(container.read(lockedProvider), isFalse);
    locked
      ..away(at)
      ..back(at.add(lockAfter));
    expect(container.read(lockedProvider), isTrue);
  });
}
