import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app_harness.dart';

void main() {
  late TempDatabases files;
  late ProviderContainer container;
  late SharedPreferences prefs;

  Future<void> start({bool demo = false}) async {
    SharedPreferences.setMockInitialValues({if (demo) 'demo_mode': true});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseOpenerProvider.overrideWithValue(files.open),
      ],
    );
  }

  Future<void> addChai() =>
      TxnRepository(container.read(appDatabaseProvider)).add(
        amountPaise: 2000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: DateTime.now(),
        merchant: 'Chai point',
      );

  Future<List<String?>> merchants() async {
    final db = container.read(appDatabaseProvider);
    return [for (final t in await db.select(db.txns).get()) t.merchant];
  }

  setUp(() => files = TempDatabases());
  tearDown(() async {
    container.dispose();
    // Let the last database finish closing before its folder goes.
    await Future<void>.delayed(Duration.zero);
    files.delete();
  });

  test('demo mode swaps in the demo, and your own money comes back', () async {
    await start();
    await addChai();
    expect(files.opened, ['penny']);

    await container.read(demoModeProvider.notifier).set(true);
    expect(prefs.getBool('demo_mode'), isTrue);
    final demo = await merchants();
    expect(demo, isNotEmpty);
    expect(demo, isNot(contains('Chai point')));
    // Filled first, then shown.
    expect(files.opened, ['penny', 'penny_demo', 'penny_demo']);

    await container.read(demoModeProvider.notifier).set(false);
    expect(prefs.getBool('demo_mode'), isFalse);
    expect(await merchants(), ['Chai point']);
    expect(files.opened.last, 'penny');
  });

  test('demo mode is remembered across restarts', () async {
    await start(demo: true);
    expect(container.read(demoModeProvider), isTrue);
    container.read(appDatabaseProvider);
    expect(files.opened, ['penny_demo']);
  });

  test('a second tap while switching is ignored', () async {
    await start();
    container.read(appDatabaseProvider);
    final notifier = container.read(demoModeProvider.notifier);

    await Future.wait([notifier.set(true), notifier.set(true)]);
    expect(await merchants(), isNotEmpty);
    // Opened once to fill and once to show: the demo is only there once.
    expect(files.opened, ['penny', 'penny_demo', 'penny_demo']);
  });
}
