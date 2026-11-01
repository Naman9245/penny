import 'package:intl/intl.dart';

// Everything is local time. A month runs from midnight on the 1st to
// midnight on the 1st of the next.

DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

DateTime nextMonth(DateTime month) => DateTime(month.year, month.month + 1);

DateTime prevMonth(DateTime month) => DateTime(month.year, month.month - 1);

DateTime dayStart(DateTime date) => DateTime(date.year, date.month, date.day);

/// [day] at the time of day of [time], so back-dated entries still sort
/// sensibly within their day.
DateTime onDay(DateTime day, DateTime time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute, time.second);

/// "Today", "Yesterday", then "Fri, 30 Oct".
String dayLabel(DateTime date, {DateTime? now}) {
  final today = dayStart(now ?? DateTime.now());
  final day = dayStart(date);
  if (day == today) return 'Today';
  if (day == DateTime(today.year, today.month, today.day - 1)) {
    return 'Yesterday';
  }
  return DateFormat('EEE, d MMM').format(day);
}

/// "November 2026".
String monthLabel(DateTime month) => DateFormat('MMMM y').format(month);
