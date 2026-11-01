import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text shared to Penny from another app, such as a bank SMS from Messages.
///
/// Android's MainActivity hands it over on the "penny/share" channel. The
/// text is held only long enough to be read; it is never stored or logged.
class ShareInbox {
  ShareInbox([this._channel = const MethodChannel('penny/share')]) {
    _channel.setMethodCallHandler(_receive);
  }

  final MethodChannel _channel;
  final _shared = StreamController<String>.broadcast();

  /// Shares that arrive while Penny is already open.
  Stream<String> get shared => _shared.stream;

  /// The share that opened Penny, if any. Asking takes it: a second call
  /// returns null.
  Future<String?> takeLaunchShare() async {
    try {
      return await _channel.invokeMethod<String>('takeSharedText');
    } on MissingPluginException {
      // No Android side, as in tests or on iOS for now.
      return null;
    }
  }

  Future<void> _receive(MethodCall call) async {
    if (call.method == 'shared' && call.arguments is String) {
      _shared.add(call.arguments as String);
    }
  }

  void dispose() {
    _channel.setMethodCallHandler(null);
    _shared.close();
  }
}

final shareInboxProvider = Provider<ShareInbox>((ref) {
  final inbox = ShareInbox();
  ref.onDispose(inbox.dispose);
  return inbox;
});
