import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';

/// The month the Analysis tab is showing. It lives here, not in the screen,
/// so Add can start in that month.
final analysisMonthProvider = NotifierProvider<ShownMonth, DateTime>(
  ShownMonth.new,
);

/// The month the Calendar tab is showing, for the same reason.
final calendarMonthProvider = NotifierProvider<ShownMonth, DateTime>(
  ShownMonth.new,
);

/// A tab's month: this month until the user steps to another.
class ShownMonth extends Notifier<DateTime> {
  @override
  DateTime build() => monthStart(DateTime.now());

  void show(DateTime month) => state = monthStart(month);
}
