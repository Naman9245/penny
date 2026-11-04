import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/txn_search.dart';

import '../helpers/txn_factory.dart';

void main() {
  final at = DateTime(2026, 11, 4, 12);

  test('words match the place or what it was for', () {
    final swiggy = txn(250, at, merchant: 'Swiggy');
    expect(matchesSearch(swiggy, 'swig'), isTrue);
    expect(matchesSearch(swiggy, '  FOOD '), isTrue);
    expect(matchesSearch(swiggy, 'travel'), isFalse);
    expect(matchesSearch(swiggy, ''), isTrue);

    final back = txn(100, at, type: TxnType.credit);
    expect(matchesSearch(back, 'paid back'), isTrue);
    expect(matchesSearch(txn(1000, at, categoryId: 'invest'), 'sip'), isTrue);
  });

  test('an amount matches those rupees, however it is written', () {
    final entries = {
      '250': txn(250, at),
      '1250': txn(1250, at),
      '2500': txn(2500, at),
      '1200': txn(1200, at),
    };
    List<String> found(String query) => [
      for (final MapEntry(:key, :value) in entries.entries)
        if (matchesSearch(value, query)) key,
    ];
    expect(found('250'), ['250']);
    expect(found('₹1,200'), ['1200']);
    expect(found('Rs 2500'), ['2500']);

    final paise = txn(0, at).copyWith(amountPaise: 25050);
    expect(matchesSearch(paise, '250'), isTrue);
    expect(matchesSearch(paise, '250.5'), isTrue);
    expect(matchesSearch(paise, '250.25'), isFalse);
  });

  test('the total line adds up each kind', () {
    expect(
      totalLine([
        txn(250, at),
        txn(480, at),
        txn(100, at, type: TxnType.credit),
        txn(5000, at, type: TxnType.credit, categoryId: 'salary'),
        txn(1000, at, categoryId: 'invest'),
      ]),
      '5 entries · spent ₹730 · got ₹5,000 · ₹100 came back · '
      '₹1,000 invested',
    );
    expect(
      totalLine([txn(60, at, categoryId: 'travel')]),
      '1 entry · spent ₹60',
    );
  });
}
