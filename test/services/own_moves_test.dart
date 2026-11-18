import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/own_moves.dart';
import 'package:penny/services/sms_parser.dart';

/// Notifications waiting, as Android's listener would hand them over.
class FakeSource implements CaptureSource {
  final waiting = <Capture>[];

  @override
  Future<({List<Capture> captures, int count})> peek() async =>
      (captures: List.of(waiting), count: waiting.length);

  @override
  Future<void> drop(int count) async => waiting.removeRange(0, count);
}

// All made up, digits included. 2:30 in the afternoon of 5 Nov.
final at = DateTime(2026, 11, 5, 14, 30);

/// PayZapp: money out of the wallet, with no shop named.
const walletOut =
    'Rs.2000 Deducted\nFrom PayZapp Wallet\nOn 05-11-2026 14:30:12\n'
    'Bal: Rs.575.88\nNot you? Report: https://1.hdfc.bank.in/HDFCBK/s/ab12cd34 '
    'or SMS BLOCKPZW to 5676712';

/// The bank: the same money in, from the wallet's UPI ID.
const bankIn =
    'Credit Alert!\nRs.2000.00 credited to HDFC Bank A/c XX4821 on 05-11-26 '
    'from VPA *1234@pzw (UPI 175566436892)';

/// The bank: money out to the wallet's UPI ID.
const bankOut =
    'Sent Rs.500.00\nFrom HDFC Bank A/C *4821\nTo 9876541234@pzw\nOn 05/11/26\n'
    'Ref 668342875499\nNot You?\nCall 18002586161/SMS BLOCK UPI to 7308080808';

/// PayZapp: the same money into the wallet.
const walletIn =
    'Rs.500.00 credited to your PayZapp Wallet on 05-11-2026. Wallet bal '
    'Rs.1075.88 -HDFC Bank';

/// PayZapp: a shop paid from the wallet. Spending.
const walletShop =
    'Paid Rs.150.00 to ZOMATO from your PayZapp Wallet on 05-11-2026. Wallet '
    'bal Rs.350.00 -HDFC Bank';

/// The bank: a friend's PayZapp paying you. Money in.
const friendIn =
    'Credit Alert!\nRs.300.00 credited to HDFC Bank A/c XX4821 on 05-11-26 '
    'from VPA *7788@pzw (UPI 175566436111)';

Capture sms(String sender, String text, {Duration after = Duration.zero}) =>
    (app: 'sms', title: sender, text: text, at: at.add(after));

void main() {
  group('half of a move', () {
    MoveHalf? half(String text, {String app = 'sms'}) =>
        moveHalfOf(app, text, parseSms(text, now: at));

    test("the wallet's side: money out of it with no shop", () {
      final out = half(walletOut)!;
      expect(out.side, MoveSide.wallet);
      expect(out.type, TxnType.debit);
      expect(out.amountPaise, 200000);
      expect(out.walletHandle, isNull);
    });

    test("the bank's side: money from or to a wallet's UPI ID", () {
      final into = half(bankIn)!;
      expect(into.side, MoveSide.bank);
      expect(into.type, TxnType.credit);
      expect(into.walletHandle, isNotNull);
      final out = half(bankOut)!;
      expect(out.side, MoveSide.bank);
      expect(out.type, TxnType.debit);
      // "*1234@pzw" and "9876541234@pzw" are the same wallet.
      expect(out.walletHandle, into.walletHandle);
    });

    test('a wallet load the rules already let go is the wallet side', () {
      expect(parseSms(walletIn, now: at), isA<SmsIgnored>());
      final into = half(walletIn)!;
      expect(into.side, MoveSide.wallet);
      expect(into.type, TxnType.credit);
      expect(into.amountPaise, 50000);
    });

    test('a shop paid from the wallet is no half', () {
      expect(half(walletShop), isNull);
    });

    test('a payment with nothing of a wallet is no half', () {
      expect(
        half(
          'Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630512345678.',
        ),
        isNull,
      );
    });
  });

  group('taking them in', () {
    late AppDatabase db;
    late TxnRepository txns;
    late CaptureRepository captures;
    late FakeSource source;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      txns = TxnRepository(db);
      captures = CaptureRepository(db);
      source = FakeSource();
    });
    tearDown(() => db.close());

    Future<List<CaptureRead>> take(
      List<Capture> captured, {
      CaptureMode mode = CaptureMode.save,
    }) {
      source.waiting.addAll(captured);
      return takeCaptures(
        source: source,
        db: db,
        txns: txns,
        captures: captures,
        mode: mode,
        now: at,
      );
    }

    Future<List<Txn>> live() =>
        (db.select(db.txns)..where((t) => t.deletedAt.isNull())).get();

    test('PayZapp to the bank: the second half takes out the first', () async {
      final first = (await take([sms('JM-HDFCBN-S', walletOut)])).single;
      expect(first.outcome, CaptureOutcome.saved);
      expect(await live(), hasLength(1));

      final second = (await take([
        sms('JX-HDFCBK-S', bankIn, after: const Duration(minutes: 1)),
      ])).single;
      expect(second.outcome, CaptureOutcome.moved);
      expect(second.entryId, first.entryId);
      expect(await live(), isEmpty);
      final notice = noticeFor([second])!;
      expect(notice.title, 'Your own money moved');
      expect(notice.text, startsWith('₹2,000 went between your wallet'));
    });

    test('the bank first, then PayZapp: the same', () async {
      final first = (await take([sms('JX-HDFCBK-S', bankIn)])).single;
      expect(first.outcome, CaptureOutcome.saved);
      final second = (await take([
        sms('JM-HDFCBN-S', walletOut, after: const Duration(minutes: 2)),
      ])).single;
      expect(second.outcome, CaptureOutcome.moved);
      expect(await live(), isEmpty);
    });

    test(
      'the bank into PayZapp: the wallet load takes out the debit',
      () async {
        final first = (await take([sms('JX-HDFCBK-S', bankOut)])).single;
        expect(first.outcome, CaptureOutcome.saved);
        final second = (await take([
          sms('JM-HDFCBN-S', walletIn, after: const Duration(minutes: 1)),
        ])).single;
        expect(second.outcome, CaptureOutcome.moved);
        expect(await live(), isEmpty);
      },
    );

    test('the wallet load first: the bank debit is never saved', () async {
      final first = (await take([sms('JM-HDFCBN-S', walletIn)])).single;
      expect(first.outcome, CaptureOutcome.letGo);
      expect(first.what, 'a move between your own accounts');
      final second = (await take([
        sms('JX-HDFCBK-S', bankOut, after: const Duration(minutes: 1)),
      ])).single;
      expect(second.outcome, CaptureOutcome.letGo);
      expect(second.what, 'a move between your own accounts');
      expect(await live(), isEmpty);
    });

    test(
      'a wallet met in a move is yours: next time alone is enough',
      () async {
        await take([sms('JM-HDFCBN-S', walletOut)]);
        await take([
          sms('JX-HDFCBK-S', bankIn, after: const Duration(minutes: 1)),
        ]);
        final later = (await take([
          sms(
            'JX-HDFCBK-S',
            bankIn
                .replaceAll('2000.00', '700.00')
                .replaceAll('175566436892', '175566439999'),
            after: const Duration(days: 1),
          ),
        ])).single;
        expect(later.outcome, CaptureOutcome.letGo);
        expect(later.what, contains('a wallet of yours'));
        expect(await live(), isEmpty);
      },
    );

    test("a friend's PayZapp paying you is money in", () async {
      final read = (await take([sms('JX-HDFCBK-S', friendIn)])).single;
      expect(read.outcome, CaptureOutcome.saved);
      expect(await live(), hasLength(1));
    });

    test('a shop paid from the wallet is spending', () async {
      final read = (await take([sms('JM-HDFCBN-S', walletShop)])).single;
      expect(read.outcome, CaptureOutcome.saved);
      expect((await live()).single.merchant, 'Zomato');
    });

    test('half an hour apart, the two stay two', () async {
      await take([sms('JM-HDFCBN-S', walletOut)]);
      await take([
        sms('JX-HDFCBK-S', bankIn, after: const Duration(minutes: 30)),
      ]);
      expect(await live(), hasLength(2));
    });

    test('waiting to be checked: the first leaves Home', () async {
      final first = (await take([
        sms('JM-HDFCBN-S', walletOut),
      ], mode: CaptureMode.check)).single;
      expect(first.outcome, CaptureOutcome.waiting);
      expect(await captures.watchWaiting().first, hasLength(1));
      final second = (await take([
        sms('JX-HDFCBK-S', bankIn, after: const Duration(minutes: 1)),
      ], mode: CaptureMode.check)).single;
      expect(second.outcome, CaptureOutcome.letGo);
      expect(await captures.watchWaiting().first, isEmpty);
      expect(await live(), isEmpty);
    });

    test('read again later, a half is known and passed over', () async {
      await take([sms('JM-HDFCBN-S', walletOut)]);
      final again = sms(
        'JX-HDFCBK-S',
        bankIn,
        after: const Duration(minutes: 1),
      );
      await take([again]);
      expect(await take([again]), isEmpty);
      expect(await live(), isEmpty);
    });
  });

  group('moves saved before Penny knew', () {
    late AppDatabase db;
    late TxnRepository txns;
    late CaptureRepository captures;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      txns = TxnRepository(db);
      captures = CaptureRepository(db);
    });
    tearDown(() => db.close());

    /// [text] saved as an older Penny did: as money in or out.
    Future<String> savedBefore(
      String sender,
      String text,
      DateTime when, {
      bool withHandle = false,
    }) async {
      final read = parseSms(text, now: when) as SmsTxn;
      final id = await txns.add(
        amountPaise: read.amountPaise,
        type: read.type,
        categoryId: read.type == TxnType.debit ? 'other' : 'from_people',
        occurredAt: when,
        source: TxnSource.sms,
        dedupeKey: read.dedupeKey,
        payeeIsPerson: read.payeeIsPerson,
      );
      await captures.recordSaved(
        read,
        app: 'sms',
        at: when,
        entryId: id,
        sender: sender,
        walletHandle: withHandle ? walletHandleOf(text) : null,
      );
      return id;
    }

    Future<List<Txn>> live() =>
        (db.select(db.txns)..where((t) => t.deletedAt.isNull())).get();

    test('the pair is found, taken out, and put back', () async {
      final out = await savedBefore('JM-HDFCBN-S', walletOut, at);
      final into = await savedBefore(
        'JX-HDFCBK-S',
        bankIn,
        at.add(const Duration(minutes: 1)),
      );
      final moves = await pastMovesOf(db, at.subtract(pastMovesLookBack));
      final move = moves.single;
      expect(move.walletEntry, out);
      expect(move.bankEntry, into);
      expect(move.amountPaise, 200000);
      expect(move.toBank, isTrue);

      await removePastMove(db, txns, move, now: at);
      expect(await live(), isEmpty);
      expect(await pastMovesOf(db, at.subtract(pastMovesLookBack)), isEmpty);

      await putBackMove(db, txns, [move.walletEntry, move.bankEntry]);
      expect(await live(), hasLength(2));
    });

    test(
      'a payment and money back the other way, apart, are no pair',
      () async {
        await savedBefore('JM-HDFCBN-S', walletOut, at);
        await savedBefore('JX-HDFCBK-S', friendIn, at);
        expect(await pastMovesOf(db, at.subtract(pastMovesLookBack)), isEmpty);
      },
    );

    test('"This was my own money" takes out both halves', () async {
      await savedBefore('JM-HDFCBN-S', walletOut, at);
      final into = await savedBefore(
        'JX-HDFCBK-S',
        bankIn,
        at.add(const Duration(minutes: 1)),
        withHandle: true,
      );
      final removed = await markOwnMove(db, txns, into, now: at);
      expect(removed, hasLength(2));
      expect(await live(), isEmpty);
      // The wallet is remembered as the user's.
      expect(await isYourWallet(db, walletHandleOf(bankIn)), isTrue);

      await putBackMove(db, txns, removed);
      expect(await live(), hasLength(2));
      expect(await isYourWallet(db, walletHandleOf(bankIn)), isFalse);
    });

    test('alone, "This was my own money" takes out just that one', () async {
      final into = await savedBefore('JX-HDFCBK-S', friendIn, at);
      expect(await markOwnMove(db, txns, into, now: at), [into]);
      expect(await live(), isEmpty);
    });
  });
}
