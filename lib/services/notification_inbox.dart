import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One notification Penny read, as the Android listener kept it: from the
/// SMS app ("sms"), a payment app ("gpay", "phonepe", "paytm"), or a wallet
/// or investing app ("payzapp", "groww" and the others in
/// PaymentNotificationListener.kt).
typedef Capture = ({String app, String title, String text, DateTime at});

/// A batch of a look back at older SMS: how many money ones were queued,
/// when the last one looked at came, and whether that was all of them.
typedef SmsLookBack = ({int kept, DateTime? until, bool done});

/// What Penny's own notification says: a title, a line, and one line each
/// when it's about several payments.
typedef PennyNotice = ({String title, String text, List<String> lines});

/// Where captures wait: Android's listener, or a fake in tests.
abstract interface class CaptureSource {
  /// Everything waiting, oldest first, and how many there were in all.
  Future<({List<Capture> captures, int count})> peek();

  /// Forgets the oldest [count], once they're kept.
  Future<void> drop(int count);
}

/// Payment notifications waiting on the "penny/notifications" channel.
///
/// Android's PaymentNotificationListener keeps them in Penny's private
/// storage until they're read here; it reads only the SMS app and a list of
/// payment, wallet and investing apps, and only once the user allows it on
/// Android's own page.
class NotificationInbox implements CaptureSource {
  NotificationInbox([
    this._channel = const MethodChannel('penny/notifications'),
  ]) {
    _channel.setMethodCallHandler(_receive);
  }

  final MethodChannel _channel;
  final _arrived = StreamController<void>.broadcast();
  final _openHome = StreamController<void>.broadcast();
  final _refreshed = StreamController<void>.broadcast();

  /// Fires when more are waiting while Penny is open.
  Stream<void> get arrived => _arrived.stream;

  /// Fires when Penny's own notification is tapped while she's open.
  Stream<void> get openHome => _openHome.stream;

  /// Fires when Penny's hidden copy has just read payments while she's
  /// open: what it wrote isn't on screen yet.
  Stream<void> get refreshed => _refreshed.stream;

  /// For Penny's hidden copy: whether more came while she was reading.
  Future<bool> again() async => await _call<bool>('again') ?? false;

  /// For Penny's hidden copy: she's finished, so Android can close her.
  Future<void> done() => _call<void>('done');

  /// Whether the user has allowed Penny to read notifications.
  Future<bool> isAllowed() async => await _call<bool>('isEnabled') ?? false;

  /// Opens Android's page where the user allows it.
  Future<void> openSettings() => _call<void>('openSettings');

  /// Whether Penny may post her own notifications.
  Future<bool> canNotify() async => await _call<bool>('canNotify') ?? false;

  /// Asks whether Penny may post notifications: with Android's own question
  /// where it still asks it, or else, with [orSettings], on Penny's
  /// notification settings. Whether she may now.
  Future<bool> askToNotify({bool orSettings = true}) async =>
      await _call<bool>('askToNotify', orSettings) ?? false;

  /// Posts [notice] as Penny's notification, in place of the last one.
  Future<void> notify(PennyNotice notice) => _call<void>('notify', {
    'title': notice.title,
    'text': notice.text,
    'lines': notice.lines,
  });

  /// Anything unreadable is left out of the captures, and dropped with the
  /// rest.
  @override
  Future<({List<Capture> captures, int count})> peek() async {
    final json = await _call<String>('peek');
    final items = json == null ? const [] : jsonDecode(json) as List<dynamic>;
    return (
      captures: [
        for (final item in items)
          if (item case {
            'app': final String app,
            'title': final String title,
            'text': final String text,
            'at': final int at,
          })
            (
              app: app,
              title: title,
              text: text,
              at: DateTime.fromMillisecondsSinceEpoch(at),
            ),
      ],
      count: items.length,
    );
  }

  @override
  Future<void> drop(int count) => _call<void>('drop', count);

  /// Whether Penny may receive and read SMS.
  Future<bool> smsAllowed() async => await _call<bool>('smsAllowed') ?? false;

  /// Asks Android whether Penny may receive and read SMS, or opens her app
  /// settings once it won't ask again. Whether she may now.
  Future<bool> askSms() async => await _call<bool>('askSms') ?? false;

  /// Has Android's listener queue the payment notifications still showing,
  /// and any bank SMS that came since the last look, in case one was missed
  /// while it was stopped. How many were new.
  Future<int> catchUp() async => await _call<int>('catchUp') ?? 0;

  /// Has Android queue the money SMS of the last [days] days, after [after]
  /// when given, oldest first, up to [most] of them: how many were queued,
  /// the time of the last SMS looked at, and whether there are no more.
  Future<SmsLookBack> lookBack({
    required int days,
    DateTime? after,
    int most = 100,
  }) async {
    final reply = await _call<Map<Object?, Object?>>('lookBack', {
      'days': days,
      'after': ?after?.millisecondsSinceEpoch,
      'most': most,
    });
    if (reply == null) return (kept: 0, until: null, done: true);
    return (
      kept: (reply['kept'] as num?)?.toInt() ?? 0,
      until: switch (reply['until']) {
        final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
        _ => null,
      },
      done: reply['done'] != false,
    );
  }

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      // No Android side, as in tests or on iOS.
      return null;
    }
  }

  Future<void> _receive(MethodCall call) async {
    switch (call.method) {
      case 'captured':
        _arrived.add(null);
      case 'openHome':
        _openHome.add(null);
      case 'refresh':
        _refreshed.add(null);
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _arrived.close();
    _openHome.close();
    _refreshed.close();
  }
}

final notificationInboxProvider = Provider<NotificationInbox>((ref) {
  final inbox = NotificationInbox();
  ref.onDispose(inbox.dispose);
  return inbox;
});

/// Whether Penny may read notifications. Ask again when the user comes back
/// from Android's page.
final notificationAccessProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationInboxProvider).isAllowed(),
);

/// Whether Penny may read bank SMS. Ask again when the user comes back
/// from Android's settings.
final smsAccessProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationInboxProvider).smsAllowed(),
);

/// Whether Penny may post her own notifications. Ask again when the user
/// comes back from Android's settings.
final pennyNotifiesProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(notificationInboxProvider).canNotify(),
);
