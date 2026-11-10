import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/services/sms_parser.dart';

import '../helpers/fake_ai.dart';

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
      'PayZapp: paid from the wallet': (
        app(
          'payzapp',
          'Payment successful',
          '₹150 paid to Zomato from your PayZapp Wallet',
        ),
        'debit 15000 Zomato food',
      ),
      'Groww: a SIP gone through': (
        app(
          'groww',
          'SIP successful',
          'Your SIP of ₹500 in Parag Parikh Flexi Cap Fund has been processed',
        ),
        'debit 50000 Parag Parikh Flexi Cap Fund invest',
      ),
      'Groww: a nudge to invest': (
        app('groww', 'Markets are up today', 'Start a SIP with just ₹100'),
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

    test("what isn't a payment says why, in a few words", () {
      final cases = <Capture, String>{
        sms('AX-HDFCBK', 'OTP is 482913 for txn of INR 649.00 at ZOMATO.'):
            'an OTP',
        sms('Rahul', 'I paid Rs 500 for the tickets, send me your share'):
            'not from a bank',
        app('phonepe', 'Money requested', 'Rahul Kumar has requested ₹300'):
            'a request for money',
        app('phonepe', 'Electricity bill is due', 'Pay ₹1,240 by 10 Nov'):
            'a payment not made yet',
        app('paytm', 'Get ₹50 cashback', 'on your first recharge. T&C apply'):
            'an offer',
        sms('AX-HDFCBK', 'Your A/c XX4821 balance is Rs 1,000.00 on 05-Nov.'):
            'only a balance',
      };
      for (final MapEntry(key: capture, value: why) in cases.entries) {
        final explained = explainCapture(capture);
        expect(explained.payment, isNull, reason: capture.text);
        expect(explained.letGo, why, reason: capture.text);
      }
    });
  });

  group('who counts as a bank', () {
    const payZapp =
        '₹1.00 deducted from your PayZapp Wallet on 05-Nov-26. ₹9.88 bal is '
        'left in your PayZapp Wallet. Not you? Report at hdfcbank.com -HDFC Bank';
    for (final sender in [
      'HDFC Bank',
      'JM-HDFCBK',
      'JM-HDFCBK-S',
      'HDFCBK',
      'PayZapp',
      'VM-GROWWZ',
    ]) {
      test('$sender: read', () {
        final payment = explainCapture(sms(sender, payZapp)).payment!;
        expect(payment.amountPaise, 100);
        expect(payment.payee, isNull);
      });
    }

    test("a friend's money text never is, by name or by number", () {
      for (final sender in [
        'Rahul',
        'RAHUL',
        'Rahul Kumar',
        'Mom',
        '+91 98765 43210',
      ]) {
        expect(
          explainCapture(
            sms(sender, 'I paid Rs 500 for the tickets, send me your share'),
          ).letGo,
          'not from a bank',
          reason: sender,
        );
      }
    });

    test('a message naming a wallet or UPI Lite counts from any sender', () {
      final capture = sms(
        '+91 98765 43210',
        'Paid Rs.20.00 via UPI Lite to RAMESH TEA STALL on 05-11-26.',
      );
      expect(explainCapture(capture).payment!.amountPaise, 2000);
    });

    test("a lender's receipt is let go, saying why", () {
      final capture = sms(
        'BZ-BAJAJF',
        'Dear Customer, EMI of Rs.4,500.00 for your loan A/c XX8812 has been '
            'received on 05-11-26.',
      );
      expect(
        explainCapture(capture).letGo,
        'a receipt for a payment already made',
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

    Future<List<CaptureRead>> take(CaptureMode mode) => takeCaptures(
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
      final reads = await take(CaptureMode.check);
      expect(
        [for (final r in reads) '${r.outcome.name}: ${r.what}'],
        [
          'waiting: −₹250 · Swiggy',
          'letGo: not from a bank',
          'waiting: +₹500 · Rahul Kumar',
        ],
      );
      expect(source.dropped, 3);
      expect([for (final c in await waiting()) c.amountPaise], [25000, 50000]);

      // A notification shown again brings nothing new.
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      expect(await take(CaptureMode.check), isEmpty);
      expect(await waiting(), hasLength(2));
    });

    Future<List<Txn>> entries() => db.select(db.txns).get();

    test('saved straight away: a person in To people or From people, '
        "anything else Penny can't place in Other", () async {
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        app('gpay', 'Rahul Kumar', 'Paid you ₹500'),
        sms(
          'AX-HDFCBK',
          'Sent Rs.1.00 From HDFC Bank A/C *4821 To AMIT SHARMA On 05/11/26 '
              'Ref 630512340001',
        ),
        sms('HDFC Bank', '₹1.00 deducted from your PayZapp Wallet.'),
      ]);
      final reads = await take(CaptureMode.save);
      expect([
        for (final r in reads) r.outcome,
      ], everyElement(CaptureOutcome.saved));
      expect(
        [for (final r in reads) r.categoryId],
        ['food', 'from_people', 'people', 'other'],
      );
      final swiggy = (await txns.findById(reads.first.entryId!))!;
      expect(swiggy.source, TxnSource.sms);
      expect(swiggy.merchant, 'Swiggy');
      expect(swiggy.occurredAt, at);
      final rahul = (await txns.findById(reads[1].entryId!))!;
      expect(rahul.categoryId, 'from_people');
      expect(rahul.payeeIsPerson, isTrue);
      // Nothing waits.
      expect(await waiting(), isEmpty);
    });

    test('one payment seen from the bank and from GPay is kept once', () async {
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        app(
          'gpay',
          '₹250 paid to Swiggy',
          'Payment successful',
          when: at.add(const Duration(minutes: 4)),
        ),
      ]);
      final reads = await take(CaptureMode.save);
      expect(
        [for (final r in reads) '${r.outcome.name}: ${r.what}'],
        ['saved: −₹250 · Swiggy', 'letGo: already saved from SMS'],
      );
      expect(await entries(), hasLength(1));
    });

    test(
      'two payments, each seen from the bank and from GPay, are two',
      () async {
        String bank(String ref) =>
            'Sent Rs.1.00 From HDFC Bank A/C *4821 To AMIT SHARMA On 05/11/26 '
            'Ref $ref';
        Capture gpay(int minutes) => app(
          'gpay',
          '₹1 paid to Amit Sharma',
          'Payment successful',
          when: at.add(Duration(minutes: minutes)),
        );
        source.waiting.addAll([
          sms('AX-HDFCBK', bank('630512340001')),
          gpay(1),
          sms(
            'AX-HDFCBK',
            bank('630512340002'),
            when: at.add(const Duration(minutes: 5)),
          ),
          gpay(6),
        ]);
        final reads = await take(CaptureMode.save);
        expect(
          [for (final r in reads) r.outcome],
          [
            CaptureOutcome.saved,
            CaptureOutcome.letGo,
            CaptureOutcome.saved,
            CaptureOutcome.letGo,
          ],
        );
        expect(await entries(), hasLength(2));

        // GPay's notice shown again is known: nothing new.
        source.waiting.add(gpay(1));
        expect(await take(CaptureMode.save), isEmpty);
      },
    );

    test(
      'two payments of one amount from one place are two payments',
      () async {
        String sent(String ref) =>
            'Sent Rs.1.00 From HDFC Bank A/C *4821 To AMIT SHARMA On 05/11/26 '
            'Ref $ref';
        source.waiting.addAll([
          sms('JM-HDFCBK', sent('630512340001')),
          // The same bank by another route: still one place.
          sms(
            'VM-HDFCBK-S',
            sent('630512340002'),
            when: at.add(const Duration(minutes: 3)),
          ),
        ]);
        final reads = await take(CaptureMode.save);
        expect(
          [for (final r in reads) r.outcome],
          [CaptureOutcome.saved, CaptureOutcome.saved],
        );
        expect(await entries(), hasLength(2));
      },
    );

    test("a fund's confirmation days after the bank's debit is the same "
        'investment', () async {
      source.waiting.add(
        sms(
          'AX-HDFCBK',
          'Rs.500.00 debited from A/c XX4821 towards NACH ICCL MUTUAL FUND.',
        ),
      );
      await take(CaptureMode.save);
      source.waiting.add(
        sms(
          'VM-GROWWZ',
          'You have successfully invested Rs.500.00 in Parag Parikh Flexi '
              'Cap Fund via SIP.',
          when: at.add(const Duration(days: 2)),
        ),
      );
      final reads = await take(CaptureMode.save);
      expect(reads.single.what, 'already saved from SMS');
      final saved = (await entries()).single;
      expect(saved.categoryId, 'invest');
    });

    test(
      'one like an entry typed by hand that day is saved, saying so',
      () async {
        await txns.add(
          amountPaise: 25000,
          type: TxnType.debit,
          categoryId: 'food',
          occurredAt: DateTime(2026, 11, 5, 9),
          merchant: 'Lunch',
        );
        source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
        final read = (await take(CaptureMode.save)).single;
        expect(read.outcome, CaptureOutcome.saved);
        expect(read.note, '₹250 · Lunch');
        expect(await entries(), hasLength(2));
      },
    );

    test('waiting to be checked, one like an entry says which', () async {
      await txns.add(
        amountPaise: 25000,
        type: TxnType.debit,
        categoryId: 'food',
        occurredAt: DateTime(2026, 11, 5, 9),
        merchant: 'Lunch',
      );
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      expect(
        [for (final r in await take(CaptureMode.check)) r.outcome],
        [CaptureOutcome.waiting],
      );
      expect((await waiting()).single.lookalike, '₹250 · Lunch at 9:00 AM');
    });

    test('saved straight away, then undone: it waits to be checked', () async {
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      final read = (await take(CaptureMode.save)).single;
      expect(await waiting(), isEmpty);
      await txns.softDelete(read.entryId!);
      await captures.hold(
        read.sms!,
        app: read.app,
        at: read.at,
        sender: read.sender,
      );
      expect((await waiting()).single.amountPaise, 25000);
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
      await captures.markSaved(second.dedupeKey, id);
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

  group("Penny's notification", () {
    CaptureRead read(
      CaptureOutcome outcome,
      Capture capture, {
      String? entryId,
      String? note,
    }) {
      final sms = readCapture(capture)!;
      return (
        key: sms.dedupeKey,
        app: capture.app,
        sender: null,
        at: capture.at,
        outcome: outcome,
        what: whatOf(sms),
        sms: sms,
        categoryId: sms.suggestedCategoryId,
        entryId: entryId,
        note: note,
      );
    }

    final swiggy = sms('AX-HDFCBK', bankSwiggy);
    final rahul = app('gpay', 'Rahul Kumar', 'Paid you ₹500');
    final CaptureRead otp = (
      key: 'otp',
      app: 'sms',
      sender: 'AX-HDFCBK',
      at: at,
      outcome: CaptureOutcome.letGo,
      what: 'an OTP',
      sms: null,
      categoryId: null,
      entryId: null,
      note: null,
    );

    test('one waiting, with the category Penny guessed', () {
      final notice = noticeFor([read(CaptureOutcome.waiting, swiggy)])!;
      expect(notice.title, 'Penny read −₹250 · Swiggy');
      expect(notice.text, "🍔 Food? It's waiting on Home: add it or skip it.");
      expect(notice.lines, isEmpty);
    });

    test('one waiting, with no category to guess', () {
      final notice = noticeFor([read(CaptureOutcome.waiting, rahul)])!;
      expect(notice.title, 'Penny read +₹500 · Rahul Kumar');
      expect(
        notice.text,
        "It's waiting on Home: pick a category, then add it.",
      );
    });

    test('one saved straight away', () {
      final notice = noticeFor([
        read(CaptureOutcome.saved, swiggy, entryId: 'e1'),
        otp,
      ])!;
      expect(notice.title, 'Penny saved −₹250 · Swiggy');
      expect(notice.text, '🍔 Food. Open Penny to change it or undo it.');
    });

    test('one saved that may repeat an entry typed by hand', () {
      final notice = noticeFor([
        read(CaptureOutcome.saved, swiggy, entryId: 'e1', note: '₹250 · Lunch'),
      ])!;
      expect(
        notice.text,
        '🍔 Food. May repeat ₹250 · Lunch you typed. Open Penny to change it '
        'or undo it.',
      );
    });

    test('several at once, a line each', () {
      final notice = noticeFor([
        read(CaptureOutcome.saved, swiggy, entryId: 'e1'),
        otp,
        read(CaptureOutcome.waiting, rahul),
      ])!;
      expect(notice.title, 'Penny read 2 payments');
      expect(notice.text, '1 waiting on Home, 1 saved');
      expect(notice.lines, ['−₹250 · Swiggy · 🍔 Food', '+₹500 · Rahul Kumar']);
    });

    test('nothing for what she only let go', () {
      expect(noticeFor([otp]), isNull);
      expect(noticeFor(const []), isNull);
    });
  });

  group('What Penny read', () {
    late AppDatabase db;
    late PrefsRepository prefs;
    late FakeSource source;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      prefs = PrefsRepository(db, clock: () => at);
      source = FakeSource();
    });
    tearDown(() => db.close());

    Future<void> takeAndNote() async {
      final reads = await takeCaptures(
        source: source,
        db: db,
        txns: TxnRepository(db, clock: () => at),
        captures: CaptureRepository(db, clock: () => at),
        mode: CaptureMode.check,
        now: at,
      );
      await noteReads(prefs, reads);
    }

    const otpText = 'OTP is 482913 for txn of INR 649.00 at ZOMATO.';

    test('newest first, each once, never the message', () async {
      final later = at.add(const Duration(minutes: 1));
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        sms('Rahul', 'Send Rs 500 for the tickets', when: later),
        sms('AX-HDFCBK', otpText, when: later),
      ]);
      await takeAndNote();
      // Shown again: not listed twice.
      source.waiting.addAll([
        sms('AX-HDFCBK', bankSwiggy),
        sms('AX-HDFCBK', otpText, when: later),
      ]);
      await takeAndNote();

      final log = await prefs.watchCaptureLog().first;
      expect(
        [for (final e in log) '${e.app} ${e.outcome}: ${e.what}'],
        [
          'sms letGo: an OTP',
          'sms letGo: not from a bank',
          'sms waiting: −₹250 · Swiggy',
        ],
      );
      expect(log.last.at, at);

      final kept = (await db.select(db.prefs).get())
          .singleWhere((p) => p.name == PrefsRepository.captureLogName)
          .value;
      for (final text in ['482913', 'ZOMATO', '4821', 'tickets', 'UPI Ref']) {
        expect(kept, isNot(contains(text)));
      }
    });

    test('keeps the last 20', () async {
      for (var i = 1; i <= 25; i++) {
        source.waiting.add(
          sms(
            'AX-HDFCBK',
            'OTP is ${100000 + i} for txn of INR 649.00.',
            when: at.add(Duration(minutes: i)),
          ),
        );
      }
      await takeAndNote();
      final log = await prefs.watchCaptureLog().first;
      expect(log, hasLength(PrefsRepository.captureLogLength));
      expect(log.first.at, at.add(const Duration(minutes: 25)));
      expect(log.last.at, at.add(const Duration(minutes: 6)));
    });

    test("it's kept on the phone, not backed up", () async {
      source.waiting.add(sms('AX-HDFCBK', bankSwiggy));
      await takeAndNote();
      final pref = (await db.select(db.prefs).get()).single;
      expect(pref.dirty, isFalse);
    });
  });

  group("Penny's AI, for what the rules can't read", () {
    late AppDatabase db;
    late TxnRepository txns;
    late CaptureRepository captures;
    late PrefsRepository prefs;
    late FakeSource source;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      txns = TxnRepository(db, clock: () => at);
      captures = CaptureRepository(db, clock: () => at);
      prefs = PrefsRepository(db, clock: () => at);
      source = FakeSource();
    });
    tearDown(() => db.close());

    // A wallet's SMS in a shape the rules don't know.
    const odd = 'PayZapp: ₹1.00 moved to AMIT SHARMA for order 4521.';

    SmsAiRead paid(int paise, {String? payee, String? category}) => (
      payment: true,
      ownMoney: false,
      type: TxnType.debit,
      amountPaise: paise,
      categoryId: category,
      payee: payee,
    );

    Future<List<CaptureRead>> take(FakeAiClient ai) => takeCaptures(
      source: source,
      db: db,
      txns: txns,
      captures: captures,
      mode: CaptureMode.save,
      now: at,
      ai: ai,
    );

    test('reads it with names hidden, and puts them back', () async {
      final ai = FakeAiClient(read: (_) => paid(100, payee: '[w1] [w2]'));
      source.waiting.add(sms('JM-HDFCBK', odd));
      final read = (await take(ai)).single;
      expect(read.outcome, CaptureOutcome.saved);
      expect(read.categoryId, 'people');
      final entry = (await txns.findById(read.entryId!))!;
      expect(entry.amountPaise, 100);
      expect(entry.merchant, 'Amit Sharma');
      expect(entry.payeeIsPerson, isTrue);
      // What went: no name.
      expect(
        ai.smsRead.single,
        'PayZapp: ₹1.00 moved to [w1] [w2] for order 4521.',
      );
    });

    test("one it says only moved your own money is let go", () async {
      final ai = FakeAiClient(
        read: (_) => (
          payment: false,
          ownMoney: true,
          type: null,
          amountPaise: 0,
          categoryId: null,
          payee: null,
        ),
      );
      source.waiting.add(sms('JM-HDFCBK', odd));
      expect((await take(ai)).single.what, 'a move between your own accounts');
    });

    test('an amount the message never gives is never kept', () async {
      final ai = FakeAiClient(read: (_) => paid(50000));
      source.waiting.add(sms('JM-HDFCBK', odd));
      final read = (await take(ai)).single;
      expect(read.outcome, CaptureOutcome.letGo);
      expect(await db.select(db.txns).get(), isEmpty);
    });

    test('a category only of the right kind', () async {
      final ai = FakeAiClient(
        read: (_) => paid(100, payee: '[w1] [w2]', category: 'salary'),
      );
      source.waiting.add(sms('JM-HDFCBK', odd));
      expect((await take(ai)).single.categoryId, 'people');
    });

    test("offline, it waits to be read, then is, once the AI's back", () async {
      final ai = FakeAiClient(failure: const AiException(AiFailure.offline));
      source.waiting.add(sms('JM-HDFCBK', odd));
      final first = (await take(ai)).single;
      expect(first.outcome, CaptureOutcome.unread);
      expect(await prefs.unread(), hasLength(1));
      expect(
        noticeFor([first])!.title,
        "Penny couldn't read a payment message",
      );

      ai
        ..failure = null
        ..read = (_) => paid(100, payee: '[w1] [w2]');
      final second = (await take(ai)).single;
      expect(second.outcome, CaptureOutcome.saved);
      expect(await prefs.unread(), isEmpty);
    });

    test("the hidden copy keeps what waits for the AI, unasked", () async {
      final ai = FakeAiClient(failure: const AiException(AiFailure.offline));
      source.waiting.add(sms('JM-HDFCBK', odd));
      await take(ai);
      expect(await prefs.unread(), hasLength(1));

      // Another arrives while Penny is closed: both wait for the open app.
      source.waiting.add(sms('JM-HDFCBK', odd.replaceFirst('1.00', '2.00')));
      final later = FakeAiClient(failure: const AiException(AiFailure.later));
      final reads = await takeCaptures(
        source: source,
        db: db,
        txns: txns,
        captures: captures,
        mode: CaptureMode.save,
        now: at,
        ai: later,
        retryUnread: false,
      );
      expect(reads.single.outcome, CaptureOutcome.unread);
      expect(await prefs.unread(), hasLength(2));
      expect(later.smsRead, hasLength(1), reason: 'only the new one');
    });

    test("never asked about an OTP, a friend's text, or one with no money "
        'moving', () async {
      final ai = FakeAiClient(read: (_) => paid(100));
      source.waiting.addAll([
        sms('AX-HDFCBK', 'OTP is 482913 for txn of INR 649.00 at ZOMATO.'),
        sms('Rahul', 'Rs 500 moved to Amit for the trip'),
        sms('AX-HDFCBK', 'Dear Customer, Rs.1,000 is your monthly limit now.'),
      ]);
      await take(ai);
      expect(ai.smsRead, isEmpty);
    });

    test('without the AI set up, it is let go as before', () async {
      final ai = FakeAiClient(isSetUp: false, read: (_) => paid(100));
      source.waiting.add(sms('JM-HDFCBK', odd));
      expect((await take(ai)).single.what, 'no payment in it');
      expect(ai.smsRead, isEmpty);
      expect(await prefs.unread(), isEmpty);
    });
  });

  group('money back for a payment', () {
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

    // All made up, in the shape HDFC sends.
    const reversal =
        'HDFC Bank : Your UPI transaction of 641.00 has been reversed in your '
        'account due to technical problem (UPI Ref no. 667600000001)';

    Future<List<CaptureRead>> take(CaptureMode mode) => takeCaptures(
      source: source,
      db: db,
      txns: txns,
      captures: captures,
      mode: mode,
      now: at,
    );

    Future<void> paid({
      int paise = 64100,
      Duration ago = const Duration(hours: 2),
    }) => txns.add(
      amountPaise: paise,
      type: TxnType.debit,
      categoryId: 'food',
      occurredAt: at.subtract(ago),
      merchant: 'Swiggy',
    );

    test(
      'cancels the payment it gives back, so Spent goes back down',
      () async {
        await paid();
        source.waiting.add(sms('HDFC Bank', reversal));
        final read = (await take(CaptureMode.save)).single;
        expect(read.outcome, CaptureOutcome.saved);
        expect(read.what, '+₹641 · Swiggy (money back)');
        expect(read.categoryId, 'food');
        final entry = (await txns.findById(read.entryId!))!;
        expect(entry.type, TxnType.credit);
        expect(entry.merchant, 'Swiggy');
        expect(MoneyKind.of(entry.type, entry.categoryId), MoneyKind.paidBack);
        final totals = MoneyTotals.of(await db.select(db.txns).get());
        expect(totals.spentPaise, 0);
        expect(totals.gotPaise, 0);
      },
    );

    test('with no payment it gives back, it is a refund', () async {
      source.waiting.add(sms('HDFC Bank', reversal));
      final read = (await take(CaptureMode.save)).single;
      expect(read.categoryId, 'refund');
      expect(read.what, '+₹641 · Got');
    });

    test(
      'a payment of another amount, or over a week old, is not it',
      () async {
        await paid(paise: 50000);
        await paid(ago: const Duration(days: 8));
        source.waiting.add(sms('HDFC Bank', reversal));
        expect((await take(CaptureMode.save)).single.categoryId, 'refund');
      },
    );

    test('read before its payment, it still cancels it', () async {
      source.waiting.addAll([
        sms(
          'HDFC Bank',
          reversal,
          when: at.subtract(const Duration(minutes: 4)),
        ),
        sms(
          'AX-HDFCBK',
          'Rs.641.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630500000003.',
        ),
      ]);
      await take(CaptureMode.save);
      final all = await db.select(db.txns).get();
      expect(all, hasLength(2));
      expect({for (final t in all) t.categoryId}, {'food'});
      final totals = MoneyTotals.of(all);
      expect(totals.spentPaise, 0);
      expect(totals.gotPaise, 0);
    });

    test('money from someone is pay only when the message says so', () async {
      source.waiting.add(
        sms(
          'JM-HDFCBK',
          'Credit Alert!\nRs.3000.00 credited to HDFC Bank A/c XX4821 on 05-11-26 '
              'from VPA *amit@okhdfcbank (UPI 132400000002)',
        ),
      );
      expect((await take(CaptureMode.save)).single.categoryId, 'from_people');
    });

    test(
      'waiting to be checked, it waits as money back for that payment',
      () async {
        await paid();
        source.waiting.add(sms('HDFC Bank', reversal));
        await take(CaptureMode.check);
        final held = (await captures.watchWaiting().first).single;
        expect(held.suggestedCategoryId, 'food');
        expect(held.payee, 'Swiggy');
        expect(held.type, TxnType.credit);
      },
    );
  });
}
