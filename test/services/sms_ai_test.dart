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
}
