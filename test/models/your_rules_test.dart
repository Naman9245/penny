import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';

import '../helpers/txn_factory.dart';

void main() {
  final day = DateTime(2026, 11, 2);
  const rules = YourRules(
    categories: {'food': TxnTag.necessary, 'fun': TxnTag.wasteful},
    shops: {'swiggy': TxnTag.wasteful},
  );

  test('a shop rule beats its category rule', () {
    expect(rules.of(txn(300, day, merchant: ' SWIGGY ')), TxnTag.wasteful);
    expect(rules.of(txn(300, day, merchant: 'Canteen')), TxnTag.necessary);
    expect(rules.of(txn(300, day)), TxnTag.necessary);
  });

  test('nothing covers income or a category with no rule', () {
    expect(
      rules.of(txn(5000, day, type: TxnType.credit, categoryId: 'fun')),
      isNull,
    );
    expect(rules.of(txn(300, day, categoryId: 'travel')), isNull);
    expect(YourRules.none.of(txn(300, day, merchant: 'Swiggy')), isNull);
  });

  test('shop names compare the way groups do', () {
    expect(shopKey('  Chai   Point '), 'chai point');
    expect(shopKey('   '), isNull);
    expect(shopKey(null), isNull);
  });
}
