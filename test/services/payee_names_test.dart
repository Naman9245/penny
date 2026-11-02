import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/payee_names.dart';

import '../helpers/txn_factory.dart';

void main() {
  // Payee names as people type them, with what Penny may see of each. Add a
  // row whenever a real kind of name comes out wrong.
  final dataset = jsonDecode(
    File('test/fixtures/payee_names.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final names = [
    for (final row in (dataset['names']! as List).cast<Map<String, Object?>>())
      (typed: row['typed']! as String, sees: row['penny_sees'] as String?),
  ];
  final day = DateTime(2026, 11, 3);

  test('every typed name goes to Penny as the dataset says', () {
    expect(names, hasLength(greaterThan(80)));
    for (final (:typed, :sees) in names) {
      expect(safePayeeName(typed), sees, reason: typed);
    }
  });

  test('a typed name with no word Penny knows counts as a person', () {
    for (final (:typed, :sees) in names) {
      expect(
        isPersonPayee(txn(100, day, merchant: typed)),
        sees == null,
        reason: typed,
      );
    }
  });

  test('what an SMS said about the payee beats the typed name', () {
    expect(
      isPersonPayee(txn(100, day, merchant: 'Cook', payeeIsPerson: true)),
      isTrue,
    );
    expect(
      isPersonPayee(
        txn(100, day, merchant: 'Rahul Kumar', payeeIsPerson: false),
      ),
      isFalse,
    );
  });
}
