import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/txn_enums.dart';

// Autopays: when each goes out next, what they come to a month, and when
// Penny reminds about them. All worked out on the phone.

/// How long after its day an autopay still counts as due, in case the
/// money goes out late.
const autopayGrace = Duration(days: 3);

/// Days before an autopay that Penny reminds, and the hour she does it.
const reminderDays = [5, 1];
const reminderHour = 10;

/// Words that say who an autopay is to, less the ones every company has:
/// "spotify" for "SPOTIFY INDIA PVT LTD" and "Spotify".
String autopayKey(String name) => name
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty && !_everyCompany.contains(word))
    .take(2)
    .join(' ');

const _everyCompany = {
  'india',
  'pvt',
  'private',
  'ltd',
  'limited',
  'llp',
  'inc',
  'co',
  'company',
  'the',
  'technologies',
  'technology',
  'tech',
  'services',
  'service',
  'solutions',
  'payments',
  'payment',
  'autopay',
  'mandate',
  'upi',
  'nach',
  'digital',
  'online',
};

/// Whether [a] and [b] name the same autopay: "Spotify" and "SPOTIFY INDIA
/// PVT LTD", "Groww" and "Groww Invest Tech". "Google Play" and "Google
/// One" are two.
bool sameAutopay(String a, String b) {
  final one = autopayKey(a);
  final other = autopayKey(b);
  if (one.isEmpty || other.isEmpty) return false;
  if (one == other) return true;
  final ones = one.split(' ');
  final others = other.split(' ');
  return ones.first == others.first && (ones.length == 1 || others.length == 1);
}

/// The day after [on] that an autopay [every] goes out again. A monthly one
/// on the 31st goes out on the last day of a shorter month.
DateTime nextAfter(DateTime on, AutopayEvery every) {
  if (every == AutopayEvery.weekly) {
    return DateTime(on.year, on.month, on.day + 7);
  }
  final months = switch (every) {
    AutopayEvery.monthly => 1,
    AutopayEvery.quarterly => 3,
    _ => 12,
  };
  final target = DateTime(on.year, on.month + months);
  final last = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(target.year, target.month, math.min(on.day, last));
}

/// Whether [autopay] still goes out: not ended, paused or deleted.
bool isActive(Autopay autopay) =>
    autopay.endedAt == null && !autopay.paused && autopay.deletedAt == null;

/// The next day [autopay] goes out, as of [today]: its next day, moved on
/// past any that went by without it, unless they were within
/// [autopayGrace]. Null when the day isn't known.
DateTime? dueOn(Autopay autopay, DateTime today) {
  var due = autopay.nextOn;
  if (due == null) return null;
  due = dayStart(due);
  final from = dayStart(today).subtract(autopayGrace);
  while (due!.isBefore(from)) {
    due = nextAfter(due, autopay.every);
  }
  return due;
}

/// What [autopays] that still go out come to in a month: a weekly one 52
/// times a year, a yearly one a twelfth.
int monthlyPaise(Iterable<Autopay> autopays) {
  var total = 0.0;
  for (final autopay in autopays.where(isActive)) {
    total += switch (autopay.every) {
      AutopayEvery.weekly => autopay.amountPaise * 52 / 12,
      AutopayEvery.monthly => autopay.amountPaise.toDouble(),
      AutopayEvery.quarterly => autopay.amountPaise / 3,
      AutopayEvery.yearly => autopay.amountPaise / 12,
    };
  }
  return total.round();
}

/// A reminder for Android to show at [at]: [id] stays the same for the
/// same autopay, day and lead, so scheduling again replaces it.
typedef Reminder = ({int id, DateTime at, String title, String text});

/// Penny's reminders for [autopays] from [now] on: [reminderDays] before
/// each one's next day, at [reminderHour], in her own words. Ones already
/// past are left out.
List<Reminder> remindersFor(Iterable<Autopay> autopays, DateTime now) {
  final reminders = <Reminder>[];
  for (final autopay in autopays.where(isActive)) {
    final due = dueOn(autopay, now);
    if (due == null) continue;
    final amount = formatPaise(autopay.amountPaise);
    for (final days in reminderDays) {
      final at = DateTime(due.year, due.month, due.day - days, reminderHour);
      if (!at.isAfter(now)) continue;
      reminders.add((
        id: _reminderId(autopay.id, due, days),
        at: at,
        title: days == 1
            ? '${autopay.name} autopay tomorrow'
            : 'Psst! ${autopay.name} in $days days',
        text: days == 1
            ? "$amount goes out tomorrow. Penny's ready to note it 🙂"
            : '$amount goes out on ${DateFormat('EEEE, d MMM').format(due)}. '
                  'Keep a little extra in the bank 🎧',
      ));
    }
  }
  return reminders..sort((a, b) => a.at.compareTo(b.at));
}

int _reminderId(String autopayId, DateTime due, int days) =>
    Object.hash(autopayId, due.year, due.month, due.day, days) & 0x7fffffff;

/// One line about [autopay]: "₹139 every month · next Sun, 23 Nov", or why
/// it doesn't go out.
String autopayLine(Autopay autopay, DateTime today) {
  final amount = formatPaise(autopay.amountPaise);
  if (autopay.endedAt != null) return '$amount · cancelled';
  if (autopay.paused) return '$amount ${autopay.every.label} · paused';
  final due = dueOn(autopay, today);
  return due == null
      ? '$amount ${autopay.every.label} · next day not known yet'
      : '$amount ${autopay.every.label} · next ${dayLabel(due, now: today)}';
}
