import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/merchant_categories.dart';

void main() {
  String? spend(String payee) =>
      suggestCategory(type: TxnType.debit, text: '', payee: payee);

  test('known merchants land in their category', () {
    expect(spend('Swiggy'), 'food');
    expect(spend('Blinkit'), 'groceries');
    expect(spend('Uber India Systems Pvt Ltd'), 'travel');
    expect(spend('Amazon'), 'shopping');
    expect(spend('Jio Prepaid'), 'bills');
    expect(spend('Netflix'), 'subscriptions');
  });

  test('Amazon Prime is a subscription, not shopping', () {
    expect(spend('Amazon Prime'), 'subscriptions');
  });

  test('keywords match whole words only', () {
    expect(spend('Busy Bee Traders'), isNull);
    expect(spend('Rahul Kumar'), isNull);
  });

  test('the message text is a fallback when the payee says nothing', () {
    expect(
      suggestCategory(type: TxnType.debit, text: 'Spent INR 799 SPOTIFY INDIA'),
      'subscriptions',
    );
  });

  test('income: refunds, cashback and salaries', () {
    expect(
      suggestCategory(type: TxnType.credit, text: 'Refund of Rs.399 credited'),
      'refund',
    );
    expect(
      suggestCategory(type: TxnType.credit, text: 'Cashback of Rs.25 credited'),
      'refund',
    );
    expect(
      suggestCategory(type: TxnType.credit, text: 'credited by SALARY OCT26'),
      'salary',
    );
    expect(
      suggestCategory(
        type: TxnType.credit,
        text: 'deposited for NEFT Cr-ICIC0000104-ACME TECHNOLOGIES PVT LTD-',
        payee: 'Acme Technologies Pvt Ltd',
      ),
      'salary',
    );
    expect(
      suggestCategory(
        type: TxnType.credit,
        text: 'credited from KARAN MEHTA',
        payee: 'Karan Mehta',
      ),
      isNull,
    );
  });
}
