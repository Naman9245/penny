import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/money.dart';

void main() {
  group('formatPaise', () {
    test('drops paise when the amount is whole', () {
      expect(formatPaise(25000), '₹250');
      expect(formatPaise(0), '₹0');
    });

    test('keeps two decimals otherwise', () {
      expect(formatPaise(24950), '₹249.50');
      expect(formatPaise(24905), '₹249.05');
    });

    test('groups the Indian way', () {
      expect(formatPaise(10151300), '₹1,01,513');
      expect(formatPaise(1000000000), '₹1,00,00,000');
    });

    test('marks negatives with a minus sign', () {
      expect(formatPaise(-25000), '−₹250');
    });
  });

  group('applyAmountKey', () {
    String type(String keys) => keys.split('').fold('', applyAmountKey);

    test('builds digits and replaces a lone zero', () {
      expect(type('250'), '250');
      expect(type('05'), '5');
      expect(type('00'), '0');
    });

    test('starts decimals with 0. and allows one point', () {
      expect(type('.'), '0.');
      expect(type('12..5'), '12.5');
    });

    test('rejects a third decimal', () {
      expect(type('249.555'), '249.55');
    });

    test('caps whole rupees at seven digits', () {
      expect(type('123456789'), '1234567');
      expect(type('1234567.89'), '1234567.89');
    });
  });

  test('dropAmountKey removes the last character', () {
    expect(dropAmountKey('249.5'), '249.');
    expect(dropAmountKey(''), '');
  });

  group('amountTextToPaise', () {
    test('reads partial input', () {
      expect(amountTextToPaise(''), 0);
      expect(amountTextToPaise('0.'), 0);
      expect(amountTextToPaise('249.5'), 24950);
      expect(amountTextToPaise('249.05'), 24905);
      expect(amountTextToPaise('1000'), 100000);
    });

    test('round-trips with paiseToAmountText', () {
      for (final paise in [1, 50, 100, 24950, 10151300]) {
        expect(amountTextToPaise(paiseToAmountText(paise)), paise);
      }
    });
  });

  test('formatAmountText groups what was typed', () {
    expect(formatAmountText(''), '₹0');
    expect(formatAmountText('0.'), '₹0.');
    expect(formatAmountText('123456.5'), '₹1,23,456.5');
  });

  group('sums', () {
    String type(String keys) => keys.split('').fold('', applySumKey);

    test('add and take away, each term typed like an amount', () {
      expect(type('3000+2500−200'), '3000+2500-200');
      expect(sumTextToPaise('3000+2500-200'), 530000);
      expect(type('12.555+05'), '12.55+5');
      expect(sumTextToPaise('12.55+5'), 1755);
    });

    test('a second operator replaces the first', () {
      expect(type('50+−'), '50-');
      expect(type('50−+'), '50+');
    });

    test('a sum can start with a minus, never a plus', () {
      expect(type('+'), '');
      expect(type('−50'), '-50');
      expect(type('−+'), '-');
      expect(sumTextToPaise('-50'), -5000);
    });

    test('a trailing point goes before an operator', () {
      expect(type('30.+'), '30+');
    });

    test('stops at ten terms', () {
      final keys = List.filled(12, '1').join('+');
      expect(type(keys).split('+'), hasLength(kMaxSumTerms));
    });

    test('partial terms count as nothing', () {
      expect(sumTextToPaise(''), 0);
      expect(sumTextToPaise('3000+'), 300000);
      expect(sumTextToPaise('3000-0.'), 300000);
      expect(sumTextToPaise('200-500'), -30000);
    });

    test('shown with rupees and real minus signs', () {
      expect(isSum('3000'), isFalse);
      expect(formatSumText('3000'), '₹3,000');
      expect(formatSumText('3000+2500-200'), '₹3,000 + ₹2,500 − ₹200');
      expect(formatSumText('3000+'), '₹3,000 +');
      expect(formatSumText('-50'), '− ₹50');
    });
  });
}
