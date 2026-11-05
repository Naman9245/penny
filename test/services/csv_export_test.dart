import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/csv_export.dart';

import '../helpers/txn_factory.dart';

void main() {
  test('one row each, oldest first, every kind of money', () {
    final csv = entriesCsv([
      txn(1000, DateTime(2026, 11, 2, 10), categoryId: 'invest'),
      txn(
        250,
        DateTime(2026, 11, 1, 21, 5),
        merchant: 'Swiggy',
        tag: TxnTag.wasteful,
        source: TxnSource.sms,
      ),
      txn(300, DateTime(2026, 11, 3, 9), type: TxnType.credit),
      txn(
        15000,
        DateTime(2026, 11, 1, 9),
        type: TxnType.credit,
        categoryId: 'pocket_money',
        source: TxnSource.share,
      ),
    ]);

    expect(csv.startsWith('﻿'), isTrue);
    expect(csv.substring(1).split('\r\n'), [
      'Date,Time,Kind,Category,Place,Amount (₹),Your tag,Added',
      '2026-11-01,09:00,Got,Pocket money,,15000.00,,Shared SMS',
      '2026-11-01,21:05,Spent,Food,Swiggy,250.00,Wasteful,Read automatically',
      '2026-11-02,10:00,Invested,Invest / SIP,,1000.00,,Typed',
      '2026-11-03,09:00,Paid back,Food,,300.00,,Typed',
      '',
    ]);
  });

  test('awkward places stay in their cell, and never run as a formula', () {
    final at = DateTime(2026, 11, 1, 12);
    String placeCell(String place) =>
        entriesCsv([txn(100, at, merchant: place)])
            .split('\r\n')[1]
            .split(',Food,')[1]
            .split(',100.00')[0];

    expect(placeCell('Chai, Co.'), '"Chai, Co."');
    expect(placeCell('The "Good" Cafe'), '"The ""Good"" Cafe"');
    expect(placeCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
    expect(placeCell('+91 Stores'), "'+91 Stores");
  });

  test("the file says the day, and when it's the demo's", () {
    final today = DateTime(2026, 11, 5);
    expect(exportFileName(today, demo: false), 'penny-entries-2026-11-05.csv');
    expect(
      exportFileName(today, demo: true),
      'penny-demo-entries-2026-11-05.csv',
    );
  });
}
