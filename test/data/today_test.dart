import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/providers.dart';

// testWidgets runs on a fake clock, so these can fast-forward to midnight.
// Each disposes its container before it ends, which cancels the midnight
// timer before the test checks for timers left running.
void main() {
  testWidgets('today moves on by itself at midnight', (tester) async {
    final container = ProviderContainer();
    final first = container.read(todayProvider);
    expect(first, dayStart(clock.now()));

    final midnight = DateTime(first.year, first.month, first.day + 1);
    await tester.pump(midnight.difference(clock.now()));
    expect(container.read(todayProvider), first);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(todayProvider), midnight);
    container.dispose();
  });

  testWidgets('a check after the phone slept catches up at once', (
    tester,
  ) async {
    final container = ProviderContainer();
    final first = container.read(todayProvider);
    final notifier = container.read(todayProvider.notifier);

    withClock(
      Clock.fixed(first.add(const Duration(days: 1, hours: 7))),
      notifier.check,
    );
    expect(
      container.read(todayProvider),
      DateTime(first.year, first.month, first.day + 1),
    );
    container.dispose();
  });
}
