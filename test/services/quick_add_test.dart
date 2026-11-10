import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/quick_add.dart';

import '../helpers/txn_factory.dart';

void main() {
  group('an entry typed in one go', () {
    const cases = <String, TypedEntry?>{
      '240 swiggy': (amountPaise: 24000, place: 'swiggy', categoryId: 'food'),
      'auto 45': (amountPaise: 4500, place: 'auto', categoryId: 'travel'),
      '₹1,200 rent': (amountPaise: 120000, place: 'rent', categoryId: 'rent'),
      'Swiggy 240.50': (
        amountPaise: 24050,
        place: 'Swiggy',
        categoryId: 'food',
      ),
      'Rs 60 Metro': (amountPaise: 6000, place: 'Metro', categoryId: 'travel'),
      'Rs.20 Chai point': (
        amountPaise: 2000,
        place: 'Chai point',
        categoryId: 'food',
      ),
      '8,500/- Sunrise PG': (
        amountPaise: 850000,
        place: 'Sunrise PG',
        categoryId: 'rent',
      ),
      '1,00,000 laptop': (
        amountPaise: 10000000,
        place: 'laptop',
        categoryId: null,
      ),
      '1,000': (amountPaise: 100000, place: null, categoryId: null),
      '99₹ Mrs Kumar': (
        amountPaise: 9900,
        place: 'Mrs Kumar',
        categoryId: null,
      ),
      // Typed, a fee is for studies and an apple is fruit.
      'fees 5000': (
        amountPaise: 500000,
        place: 'fees',
        categoryId: 'education',
      ),
      'school fees 12000': (
        amountPaise: 1200000,
        place: 'school fees',
        categoryId: 'education',
      ),
      'late fee 500': (
        amountPaise: 50000,
        place: 'late fee',
        categoryId: 'charges',
      ),
      'apple 60': (amountPaise: 6000, place: 'apple', categoryId: 'groceries'),
      'apple music 99': (
        amountPaise: 9900,
        place: 'apple music',
        categoryId: 'subscriptions',
      ),
      // No amount, so it's just a place.
      'Swiggy': null,
      '': null,
      '0 chai': null,
      // Two amounts can't both be it.
      '2 samosa 30': null,
      // More than the keypad takes.
      '12345678 car': null,
      '240.505 swiggy': null,
    };
    for (final MapEntry(key: text, value: expected) in cases.entries) {
      test('"$text"', () {
        expect(readTypedEntry(text, type: TxnType.debit), expected);
      });
    }

    test('money in is guessed from words for money in', () {
      expect(readTypedEntry('50000 salary', type: TxnType.credit), (
        amountPaise: 5000000,
        place: 'salary',
        categoryId: 'salary',
      ));
      expect(
        readTypedEntry('2000 pocket money', type: TxnType.credit)?.categoryId,
        'pocket_money',
      );
      // A spend word never gives money in a spend category.
      expect(
        readTypedEntry('300 swiggy', type: TxnType.credit)?.categoryId,
        isNull,
      );
    });
  });

  group('usual entries', () {
    final now = DateTime(2026, 11, 4, 18);
    DateTime daysAgo(int days) => now.subtract(Duration(days: days));

    test('seen at least twice, the most often first', () {
      final txns = [
        txn(20, daysAgo(1), merchant: 'Chai point'),
        txn(60, daysAgo(1), categoryId: 'travel', merchant: 'Metro'),
        txn(20, daysAgo(2), merchant: 'Chai point'),
        txn(60, daysAgo(3), categoryId: 'travel', merchant: 'Metro'),
        txn(20, daysAgo(4), merchant: 'Chai point'),
        // Once only.
        txn(450, daysAgo(5), categoryId: 'shopping', merchant: 'Myntra'),
        // The same place for another amount is another entry.
        txn(25, daysAgo(6), merchant: 'Chai point'),
      ];
      expect(usualEntries(txns, TxnType.debit), [
        (categoryId: 'food', place: 'Chai point', amountPaise: 2000),
        (categoryId: 'travel', place: 'Metro', amountPaise: 6000),
      ]);
    });

    test('equals go latest first, with the latest spelling', () {
      final txns = [
        txn(60, daysAgo(9), categoryId: 'travel', merchant: 'metro'),
        txn(20, daysAgo(2), merchant: 'chai point'),
        txn(60, daysAgo(8), categoryId: 'travel', merchant: 'METRO'),
        txn(20, daysAgo(1), merchant: 'Chai Point '),
      ];
      expect(usualEntries(txns, TxnType.debit), [
        (categoryId: 'food', place: 'Chai Point', amountPaise: 2000),
        (categoryId: 'travel', place: 'METRO', amountPaise: 6000),
      ]);
    });

    test('an entry without a place still counts', () {
      final txns = [txn(15, daysAgo(1)), txn(15, daysAgo(2), merchant: ' ')];
      expect(usualEntries(txns, TxnType.debit), [
        (categoryId: 'food', place: null, amountPaise: 1500),
      ]);
    });

    test('only the kind asked for, and at most four', () {
      final txns = [
        for (final rupees in [10, 20, 30, 40, 50])
          for (final days in [1, 2]) txn(rupees, daysAgo(days)),
        for (final days in [1, 2])
          txn(
            500,
            daysAgo(days),
            type: TxnType.credit,
            categoryId: 'pocket_money',
          ),
      ];
      expect(usualEntries(txns, TxnType.debit), hasLength(4));
      expect(usualEntries(txns, TxnType.credit), [
        (categoryId: 'pocket_money', place: null, amountPaise: 50000),
      ]);
    });
  });
}
