import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/sms_ai.dart';

void main() {
  // All made up.
  test('names and places go as tags; money words, amounts and known shops '
      'stay; account and reference numbers are hidden', () {
    final masked = maskForAi(
      'Rs.1.00 sent to Amit Sharma via PayZapp from A/c XX4821 at Swiggy, '
      'Koramangala on 05-Nov-26. Ref 630512340001',
    );
    expect(
      masked.text,
      'Rs.1.00 sent to [w1] [w2] via PayZapp from A/c ••• at Swiggy, [w3] '
      'on 05-Nov-26. Ref •••',
    );
    expect(masked.tags, {
      '[w1]': 'Amit',
      '[w2]': 'Sharma',
      '[w3]': 'Koramangala',
    });
  });

  test('the same word is the same tag, in any case', () {
    final masked = maskForAi('AMIT paid you. Amit Sharma');
    expect(masked.text, '[w1] paid you. [w1] [w2]');
  });

  test('plain lowercase words go as they are, so the AI can read them', () {
    final masked = maskForAi('PayZapp: Rs.2.00 moved to AMIT SHARMA for order 4521.');
    expect(masked.text, 'PayZapp: Rs.2.00 moved to [w1] [w2] for order 4521.');
  });

  test("a name where a payee's goes is hidden, whatever its case", () {
    final masked = maskForAi('Payment of Rs 100 received from rahul kumar');
    expect(masked.text, 'Payment of Rs 100 received from [w1] [w2]');
    expect(maskForAi('paid to amit at koramangala').text, 'paid to [w1] at [w2]');
  });

  test('a web address goes as tags', () {
    expect(
      maskForAi('Not you? Report at hdfcbank.com/report').text,
      'Not you? Report at [w1].[w2]/[w3]',
    );
  });

  test("a UPI ID's name goes as tags too", () {
    final masked = maskForAi('Rs.300 sent to rohit.k@ptyes');
    expect(masked.text, 'Rs.300 sent to [w1].[w2]@[w3]');
    expect(masked.text, isNot(contains('rohit')));
  });

  test('never more than the server takes', () {
    final masked = maskForAi('Rs.1 paid. ${'word ' * 300}');
    expect(masked.text.length, maxAiText);
  });

  test("the AI's tags are put back as the words they stand for", () {
    final tags = maskForAi('Rs.1.00 sent to Amit Sharma').tags;
    expect(unmask('[w1] [w2]', tags), 'Amit Sharma');
    expect(unmask('Swiggy', tags), 'Swiggy');
    // A tag Penny never made, or nothing: no payee.
    expect(unmask('[w9]', tags), isNull);
    expect(unmask('', tags), isNull);
    expect(unmask(null, tags), isNull);
  });

  test('long numbers go as ••• however they are spaced', () {
    expect(
      maskForAi('Ref 1234 5678 9012 and card 4111-1111-1111-1111').text,
      'Ref ••• and card •••',
    );
    expect(maskForAi('Call 98765 43210 now').text, 'Call ••• now');
    // An amount with commas, and a date, stay.
    expect(
      maskForAi('Rs.1,20,000.00 debited on 05-11-26').text,
      'Rs.1,20,000.00 debited on 05-11-26',
    );
  });
}
