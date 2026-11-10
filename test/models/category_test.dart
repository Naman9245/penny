import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/category.dart';

void main() {
  test('the one-go line names every category paid in one go', () {
    expect(
      oneGoLine,
      'Bills & recharge, Rent & PG, Subscriptions, EMIs & loans, '
      'Bank charges & fees, Education and Family are paid in one go, so '
      "Penny's mood and the calendar go by everyday spending.",
    );
  });
}
