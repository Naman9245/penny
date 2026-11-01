import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/services/share_inbox.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('penny/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('hands over the share that opened the app, once', () async {
    String? pending = 'Sent Rs.250.00 To SWIGGY';
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'takeSharedText') return null;
      final text = pending;
      pending = null;
      return text;
    });
    final inbox = ShareInbox(channel);
    addTearDown(inbox.dispose);

    expect(await inbox.takeLaunchShare(), 'Sent Rs.250.00 To SWIGGY');
    expect(await inbox.takeLaunchShare(), isNull);
  });

  test('passes on shares that arrive while the app is open', () async {
    final inbox = ShareInbox(channel);
    addTearDown(inbox.dispose);
    final next = inbox.shared.first;

    await messenger.handlePlatformMessage(
      'penny/share',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('shared', 'Received Rs.500.00'),
      ),
      (_) {},
    );

    expect(await next, 'Received Rs.500.00');
  });

  test('without an Android side there is simply no share', () async {
    final inbox = ShareInbox(const MethodChannel('penny/share-test-missing'));
    addTearDown(inbox.dispose);

    expect(await inbox.takeLaunchShare(), isNull);
  });
}
