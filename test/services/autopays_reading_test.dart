import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/data/autopay_repository.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/notification_inbox.dart';

/// Notifications waiting, as Android's listener would hand them over.
class FakeSource implements CaptureSource {
  final waiting = <Capture>[];

  @override
  Future<({List<Capture> captures, int count})> peek() async =>
      (captures: List.of(waiting), count: waiting.length);

  @override
  Future<void> drop(int count) async => waiting.removeRange(0, count);
}

// All made up, digits included. 9 in the morning of 18 Nov.
final at = DateTime(2026, 11, 18, 9);

const setUp_ =
    'Update:\nRs. 139.00 UPI mandate to SPOTIFY INDIA PVT LTD has been '
    'created from HDFC Bank A/c x4821.\nUMN:\nabcd1234ef56@okhdfcb';
const cancelled =
    'Update:\nRs. 139.00 UPI mandate to SPOTIFY INDIA PVT LTD has been '
    'cancelled from HDFC Bank A/c x4821.\nUMN:\nabcd1234ef56@okhdfcb';
const dueNote =
    'Rs.139.00 will be debited from your HDFC Bank A/c xx4821 on 23-11-2026 '
    'towards SPOTIFY INDIA PVT LTD for UPI Mandate. UMN: abc@okhdfcb';

void main() {
  late AppDatabase db;
  late FakeSource source;
  late AutopayRepository autopays;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    source = FakeSource();
    autopays = AutopayRepository(db);
  });
  tearDown(() => db.close());

  Future<CaptureRead> take(Capture capture) async {
    source.waiting.add(capture);
    final reads = await takeCaptures(
      source: source,
      db: db,
      txns: TxnRepository(db),
      captures: CaptureRepository(db),
      mode: CaptureMode.save,
      now: at,
    );
    return reads.single;
  }

  Capture sms(String text) =>
      (app: 'sms', title: 'JX-HDFCBK-S', text: text, at: at);

  test('a mandate set up adds an autopay', () async {
    final read = await take(sms(setUp_));
    expect(read.what, 'an autopay set up for Spotify India Pvt Ltd');
    final one = (await autopays.all()).single;
    expect(one.name, 'Spotify India Pvt Ltd');
    expect(one.amountPaise, 13900);
    expect(one.fromMessage, isTrue);
    expect(one.nextOn, isNull);
  });

  test("the bank's note before it goes out gives its next day", () async {
    await take(sms(setUp_));
    final read = await take(sms(dueNote));
    expect(read.what, 'coming up on 23 Nov');
    expect((await autopays.all()).single.nextOn, DateTime(2026, 11, 23));
  });

  test('a mandate cancelled ends it, and it leaves Coming up', () async {
    await take(sms(setUp_));
    await take(sms(dueNote));
    final read = await take(sms(cancelled));
    expect(read.outcome, CaptureOutcome.letGo);
    expect(read.what, 'an autopay cancelled for Spotify India Pvt Ltd');
    expect((await autopays.all()).single.endedAt, isNotNull);
    final upcoming = await db.select(db.upcomingPayments).get();
    expect(upcoming.single.dismissedAt, isNotNull);
  });

  test("an autopay paid through GPay: Penny starts knowing it", () async {
    final read = await take((
      app: 'gpay',
      title: 'Autopay successful',
      text:
          'Payment for Autopay of ₹500.00 to MUTUAL FUNDS ICCL AUTOPAY was '
          'successful',
      at: at,
    ));
    expect(read.outcome, CaptureOutcome.saved);
    final one = (await autopays.all()).single;
    expect(one.name, 'Mutual Funds ICCL');
    expect(one.amountPaise, 50000);
    expect(one.lastPaidOn, DateTime(2026, 11, 18));
    expect(one.nextOn, DateTime(2026, 12, 18));
  });

  test('a plain payment is no autopay', () async {
    await take(
      sms('Rs.250.00 debited from A/c XX4821 to SWIGGY. UPI Ref 630512345678.'),
    );
    expect(await autopays.all(), isEmpty);
  });
}
