import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/sms_parser.dart';

/// Notifications waiting, as Android's listener would hand them over.
class FakeSource implements CaptureSource {
  final waiting = <Capture>[];
  var dropped = 0;

  @override
  Future<({List<Capture> captures, int count})> peek() async =>
      (captures: List.of(waiting), count: waiting.length);

  @override
  Future<void> drop(int count) async {
    waiting.removeRange(0, count);
    dropped += count;
  }
}

void main() {
  // All made up. 2:30 in the afternoon of 5 Nov.
  final at = DateTime(2026, 11, 5, 14, 30);
  Capture sms(String sender, String text, {DateTime? when}) =>
      (app: 'sms', title: sender, text: text, at: when ?? at);
  Capture app(String name, String title, String text, {DateTime? when}) =>
      (app: name, title: title, text: text, at: when ?? at);

  const bankSwiggy =
      'Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630512345678.';

  group('which notifications are payments', () {
    final cases = <String, (Capture, String?)>{
      'a bank SMS': (sms('AX-HDFCBK', bankSwiggy), 'debit 25000 Swiggy food'),
      'a bank SMS from a saved contact, naming the account': (
        sms('HDFC Bank', 'A/c XX4821 debited by Rs 500.00 on 05-Nov-26.'),
        'debit 50000 null null',
      ),
      "a friend's text about money": (
        sms('Rahul', 'I paid Rs 500 for the tickets, send me your share'),
        null,
      ),
      "a bank's OTP": (
        sms('AX-HDFCBK', 'OTP is 482913 for txn of INR 649.00 at ZOMATO.'),
        null,
      ),
      'GPay: a friend paid you': (
        app('gpay', 'Rahul Kumar', 'Paid you ₹500'),
        'credit 50000 Rahul Kumar null',
      ),
      'GPay: you paid a shop': (
        app('gpay', '₹250 paid to Swiggy', 'Payment successful'),
        'debit 25000 Swiggy food',
      ),
      'GPay: a scratch card': (
        app('gpay', "You've won ₹25 cashback!", 'Scratch your card to claim'),
        null,
      ),
      'PhonePe: money received': (
        app('phonepe', 'Received ₹500', 'from Rahul Kumar'),
        'credit 50000 Rahul Kumar null',
      ),
      'PhonePe: paid': (
        app('phonepe', 'Paid ₹250 to Swiggy', 'Debited from HDFC Bank'),
        'debit 25000 Swiggy food',
      ),
      'PhonePe: a request': (
        app('phonepe', 'Money requested', 'Rahul Kumar has requested ₹300'),
        null,
      ),
      'PhonePe: a bill due': (
        app('phonepe', 'Electricity bill is due', 'Pay ₹1,240 by 10 Nov'),
        null,
      ),
      'Paytm: money received': (
        app('paytm', 'Money Received', '₹500 received from Rahul Kumar'),
        'credit 50000 Rahul Kumar null',
      ),
      'Paytm: an offer': (
        app('paytm', 'Get ₹50 cashback', 'on your first recharge. T&C apply'),
        null,
      ),
    };
    for (final MapEntry(key: name, value: (capture, expected))
        in cases.entries) {
      test(name, () {
        final read = readCapture(capture);
        expect(
          read == null
              ? null
              : '${read.type.name} ${read.amountPaise} ${read.payee} '
                    '${read.suggestedCategoryId}',
          expected,
        );
      });
    }

    test('a friend paying you is a person, never named to Penny', () {
      expect(
        readCapture(app('gpay', 'Rahul Kumar', 'Paid you ₹500'))!.payeeIsPerson,
        isTrue,
      );
    });
  });

  test('a payment is dated by its own time, or else its notification', () {
    final noDate = readCapture(sms('AX-HDFCBK', bankSwiggy))!;
    expect(occurredAtOf(noDate, at), at);

    final dated = readCapture(
      sms('AX-HDFCBK', 'A/c XX4821 debited by Rs 500.00 on 03-Nov-26.'),
    )!;
    expect(occurredAtOf(dated, at), DateTime(2026, 11, 3, 14, 30));
  });

  group('taking them in', () {
    late AppDatabase db;
    late TxnRepository txns;
    late CaptureRepository captures;
    late FakeSource source;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      txns = TxnRepository(db, clock: () => at);
      captures = CaptureRepository(db, clock: () => at);
      source = FakeSource();
    });
    tearDown(() => db.close());

    Future<List<SavedCapture>> take(CaptureMode mode) => takeCaptures(
      source: source,
      db: db,
      txns: txns,
      captures: captures,
      mode: mode,
      now: at,
    );

    Future<List<PendingCapture>> waiting() => captures.watchWaiting().first;

    test('waiting to be checked: each held once, the rest let go', () async {
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        sms('Rahul', 'Send Rs 500 for the tickets'),
        app('gpay', 'Rahul Kumar', 'Paid you ₹500'),
      ]);
      expect(await take(CaptureMode.check), isEmpty);
      expect(source.dropped, 3);
      expect([for (final c in await waiting()) c.amountPaise], [25000, 50000]);

      // A notification shown again brings nothing new.
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      await take(CaptureMode.check);
      expect(await waiting(), hasLength(2));
    });

    test('saved straight away when clear-cut, held when not', () async {
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        // No category to go in.
        app('gpay', 'Rahul Kumar', 'Paid you ₹500'),
      ]);
      final saved = await take(CaptureMode.save);
      expect(saved, hasLength(1));
      final entry = (await txns.findById(saved.single.id))!;
      expect(entry.source, TxnSource.sms);
      expect(entry.categoryId, 'food');
      expect(entry.merchant, 'Swiggy');
      expect(entry.occurredAt, at);
      expect([for (final c in await waiting()) c.amountPaise], [50000]);
    });

    test('one payment, seen twice, counts once', () async {
      // The bank's SMS, then GPay's notice a few minutes later.
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        app(
          'gpay',
          '₹250 paid to Swiggy',
          'Payment successful',
          when: at.add(const Duration(minutes: 4)),
        ),
      ]);
      await take(CaptureMode.save);
      final held = (await waiting()).single;
      expect(held.app, 'gpay');
      expect(held.lookalike, '₹250 · Swiggy at 2:30 PM');
    });

    test('one typed by hand the same day is a lookalike too', () async {
      await txns.add(
        amountPaise: 25000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: DateTime(2026, 11, 5, 9),
        merchant: 'Lunch',
      );
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      expect(await take(CaptureMode.save), isEmpty);
      expect((await waiting()).single.lookalike, '₹250 · Lunch at 9:00 AM');
    });

    test('skipped, or added and deleted, it never comes back', () async {
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      await take(CaptureMode.check);
      final first = (await waiting()).single;
      await captures.skip(first.dedupeKey);

      final gpay = app('gpay', 'Rahul Kumar', 'Paid you ₹500');
      source.waiting.addAll([sms('AX-HDFCBK', bankSwiggy), gpay]);
      await take(CaptureMode.check);
      final second = (await waiting()).single;
      expect(second.amountPaise, 50000);

      // Added, then the entry deleted.
      final id = await txns.add(
        amountPaise: second.amountPaise,
        type: second.type,
        categoryId: 'pocket_money',
        occurredAt: second.occurredAt,
        source: TxnSource.sms,
        dedupeKey: second.dedupeKey,
      );
      await captures.remove(second.dedupeKey);
      await txns.softDelete(id);
      source.waiting.add(gpay);
      await take(CaptureMode.check);
      expect(await waiting(), isEmpty);
    });

    test('a held one opens for review as it was read', () async {
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      await take(CaptureMode.check);
      final review = CaptureRepository.toSms((await waiting()).single);
      final read = readCapture(sms('AX-HDFCBK', bankSwiggy))!;
      expect(review.amountPaise, read.amountPaise);
      expect(review.payee, 'Swiggy');
      expect(review.suggestedCategoryId, 'food');
      expect(review.dedupeKey, read.dedupeKey);
      expect(review.preview.text, read.preview.text);
      expect(
        [for (final s in review.preview.spans) (s.start, s.end, s.kind)],
        [for (final s in read.preview.spans) (s.start, s.end, s.kind)],
      );
      expect(review.occurredAt, at);
      expect(read.preview.spans.map((s) => s.kind), contains(SpanKind.amount));
    });
  });
}
