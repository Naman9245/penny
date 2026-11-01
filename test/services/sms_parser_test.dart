import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/sms_parser.dart';

// Every message in the fixtures is made up: realistic formats, fake numbers.
final _fixtures = (jsonDecode(File('test/fixtures/sms_samples.json').readAsStringSync())
        as List)
    .cast<Map<String, dynamic>>();

final _now = DateTime(2026, 11, 5, 12);

String _two(int n) => n.toString().padLeft(2, '0');

void main() {
  test('the fixtures cover at least 60 messages, most of them HDFC', () {
    expect(_fixtures.length, greaterThanOrEqualTo(60));
    final hdfc = _fixtures.where((f) => f['bank'] == 'HDFC').length;
    expect(hdfc, greaterThan(_fixtures.length / 3));
  });

  group('fixtures', () {
    for (final fixture in _fixtures) {
      final sms = fixture['sms'] as String;
      test('${fixture['bank']}: ${fixture['case']}', () {
        final result = parseSms(sms, now: _now);
        final ignored = fixture['ignored'] as String?;
        if (ignored != null) {
          expect(result, isA<SmsIgnored>());
          expect((result as SmsIgnored).reason.name, ignored);
          return;
        }

        expect(result, isA<SmsTxn>(), reason: 'should read as a payment');
        final txn = result as SmsTxn;
        final expected = fixture['expect'] as Map<String, dynamic>;
        expect(txn.type, TxnType.values.byName(expected['type'] as String));
        expect(txn.amountPaise, expected['paise']);
        expect(txn.payee, expected['payee']);

        final date = expected['date'] as String?;
        final at = txn.occurredAt;
        expect(
          at == null ? null : '${at.year}-${_two(at.month)}-${_two(at.day)}',
          date,
        );
        if (expected.containsKey('time')) {
          expect(txn.hasTime, isTrue);
          expect('${_two(at!.hour)}:${_two(at.minute)}:${_two(at.second)}', expected['time']);
        }
        if (expected.containsKey('category')) {
          expect(txn.suggestedCategoryId, expected['category']);
        }
        if (expected.containsKey('person')) {
          expect(txn.payeeIsPerson, expected['person']);
        }
      });
    }
  });

  group('the preview hides what it should', () {
    final payments = [
      for (final fixture in _fixtures)
        if (parseSms(fixture['sms'] as String, now: _now) case final SmsTxn txn) txn,
    ];

    test('no reference, phone or long number survives', () {
      for (final txn in payments) {
        expect(txn.preview.text, isNot(matches(RegExp(r'\d{6,}'))), reason: txn.preview.text);
      }
    });

    test('account and card numbers are blanked', () {
      final account = RegExp(
        r'\b(?:a/?c|acct|account|card)(?:\s*no\.?)?(?:\s*ending(?:\s*with)?)?[\s:.]*[xX*•.]*\d{2,}',
        caseSensitive: false,
      );
      for (final txn in payments) {
        expect(account.hasMatch(txn.preview.text), isFalse, reason: txn.preview.text);
      }
    });

    test('the card tail in a "SMS BLOCK" footer is blanked too', () {
      final txn = parseSms(
        'Spent Rs.1299.00 On HDFC Bank Card 7712 At AMAZON On 2026-10-30:19:42:11 '
        'Not You? Call 18002586161/SMS BLOCK DC 7712 to 7308080808',
        now: _now,
      ) as SmsTxn;
      expect(txn.preview.text, isNot(contains('7712')));
      expect(txn.preview.text, contains('BLOCK DC ••••'));
    });

    test('UPI IDs keep only their first two letters', () {
      final preview = (parseSms(
        'Received Rs.1,000.00 in your Kotak Bank AC X8899 from rohan.das@okaxis on 31-10-26.',
        now: _now,
      ) as SmsTxn)
          .preview
          .text;
      expect(preview, contains('ro•••••••@okaxis'));
      expect(preview, isNot(contains('rohan')));
    });

    test('the amount stays readable and is marked', () {
      for (final txn in payments) {
        final span = txn.preview.spans.firstWhere((s) => s.kind == SpanKind.amount);
        expect(txn.preview.text.substring(span.start, span.end), matches(RegExp(r'\d')));
      }
    });

    test('balances are hidden', () {
      final txn = parseSms(
        'Spent Rs.1299.00 On HDFC Bank Card 7712 At AMAZON On 2026-10-30:19:42:11 Bal Rs.45210.33',
        now: _now,
      ) as SmsTxn;
      expect(txn.preview.text, isNot(contains('45210')));
      expect(txn.preview.text, contains('Rs.1299.00'));
    });
  });

  group('fingerprints', () {
    const sms = 'Sent Rs.250.00\nFrom HDFC Bank A/C *4821\nTo SWIGGY\nOn 01/11/26';

    String key(String text) => (parseSms(text, now: _now) as SmsTxn).dedupeKey;

    test('ignore spacing and letter case', () {
      expect(key(sms), key('sent  rs.250.00 from hdfc bank a/c *4821   to swiggy on 01/11/26'));
    });

    test('differ when the message differs', () {
      expect(key(sms), isNot(key(sms.replaceFirst('250.00', '260.00'))));
    });
  });

  test('dates in the future or over a year old are not believed', () {
    final future = parseSms('Sent Rs.250.00 To SWIGGY On 01/12/26 from A/C *4821', now: _now);
    final old = parseSms('Sent Rs.250.00 To SWIGGY On 01/01/24 from A/C *4821', now: _now);
    expect((future as SmsTxn).occurredAt, isNull);
    expect((old as SmsTxn).occurredAt, isNull);
  });
}
