import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/utils/dates.dart';

void main() {
  final now = DateTime(2026, 11, 1, 9, 30);

  test('dayLabel says Today and Yesterday, then the date', () {
    expect(dayLabel(DateTime(2026, 11, 1, 23, 59), now: now), 'Today');
    expect(dayLabel(DateTime(2026, 10, 31, 8), now: now), 'Yesterday');
    expect(dayLabel(DateTime(2026, 10, 30), now: now), 'Fri, 30 Oct');
  });

  test('month helpers roll over the year', () {
    expect(monthStart(DateTime(2026, 11, 20, 18)), DateTime(2026, 11));
    expect(nextMonth(DateTime(2026, 12)), DateTime(2027, 1));
    expect(prevMonth(DateTime(2026, 1)), DateTime(2025, 12));
  });

  test('onDay keeps the time of day', () {
    expect(
      onDay(DateTime(2026, 10, 28), DateTime(2026, 11, 1, 21, 15, 5)),
      DateTime(2026, 10, 28, 21, 15, 5),
    );
  });

  test('monthLabel spells out the month', () {
    expect(monthLabel(DateTime(2026, 11)), 'November 2026');
  });
}
