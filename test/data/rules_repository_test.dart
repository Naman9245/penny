import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/rules_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';

void main() {
  late AppDatabase db;
  late RulesRepository repo;
  late DateTime clock;

  setUp(() {
    clock = DateTime(2026, 11, 2, 10);
    db = AppDatabase(NativeDatabase.memory());
    repo = RulesRepository(db, clock: () => clock);
  });

  tearDown(() => db.close());

  test('rules for categories and shops come back by key', () async {
    await repo.set(RuleKind.category, 'rent', TxnTag.necessary);
    await repo.set(RuleKind.shop, 'swiggy', TxnTag.wasteful);

    final rules = await repo.watch().first;
    expect(rules.categories, {'rent': TxnTag.necessary});
    expect(rules.shops, {'swiggy': TxnTag.wasteful});
  });

  test('changing a rule keeps one live row and stamps it', () async {
    await repo.set(RuleKind.category, 'food', TxnTag.necessary);
    clock = DateTime(2026, 11, 3);
    await repo.set(RuleKind.category, 'food', TxnTag.wasteful);

    final rows = await db.select(db.tagRules).get();
    expect(rows.single.tag, TxnTag.wasteful);
    expect(rows.single.updatedAt, DateTime(2026, 11, 3));
  });

  test('handing a rule back to Penny only marks it deleted', () async {
    await repo.set(RuleKind.shop, 'swiggy', TxnTag.wasteful);
    await repo.set(RuleKind.shop, 'swiggy', null);

    expect((await repo.watch().first).shops, isEmpty);
    expect((await db.select(db.tagRules).get()).single.deletedAt, isNotNull);

    // Setting it again makes a fresh rule beside the deleted one.
    await repo.set(RuleKind.shop, 'swiggy', TxnTag.necessary);
    expect((await repo.watch().first).shops, {'swiggy': TxnTag.necessary});
    expect(await db.select(db.tagRules).get(), hasLength(2));
  });

  test('clearing a rule that was never set does nothing', () async {
    await repo.set(RuleKind.category, 'fun', null);
    expect(await db.select(db.tagRules).get(), isEmpty);
  });
}
