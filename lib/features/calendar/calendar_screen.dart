import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/router/tab_months.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/calendar/day_sheet.dart';
import 'package:penny/models/budget.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/budget_math.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/month_switcher.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/pressable_area.dart';

/// Every day of a month coloured by Penny's mood that day, so spending
/// patterns show at a glance. Tap a day for what was spent.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  @override
  Widget build(BuildContext context) {
    final month = ref.watch(calendarMonthProvider);
    final today = ref.watch(todayProvider);
    final budget = ref.watch(budgetProvider).value ?? Budget.none;
    final txns = ref.watch(monthTxnsProvider(month)).value ?? const <Txn>[];
    final everyday = budget.everydayPaise;
    final share = everyday == 0 ? null : dailySharePaise(everyday, month);
    final moods = dayMoods(
      budget: budget,
      monthTxns: txns,
      month: month,
      now: today,
      firstEntry: ref.watch(firstEntryProvider).value,
      goalDays: ref.watch(goalDaysProvider),
    );
    final summary = monthMood(
      budget: budget,
      monthTxns: txns,
      month: month,
      moods: moods,
    );

    void openDay(DateTime date) {
      final mood = moods[date.day];
      final entries = [
        for (final txn in txns)
          if (dayStart(txn.occurredAt) == date) txn,
      ];
      showDaySheet(
        context,
        date: date,
        mood: mood,
        entries: entries,
        spend: splitDaySpending(budget, entries),
        sharePaise: share,
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const Text('Mood calendar', style: AppText.h1),
          const SizedBox(height: 14),
          MonthSwitcher(
            month: month,
            onChanged: ref.read(calendarMonthProvider.notifier).show,
          ),
          const SizedBox(height: 16),
          if (share == null)
            const _SetBudget()
          else ...[
            Text(
              'Your share each day: ${formatPaise(share)}',
              style: AppText.bodyStrong,
              textAlign: TextAlign.center,
            ),
            Text(
              shareExplained(everyday, month),
              key: const ValueKey('share-explained'),
              style: AppText.small,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 14),
          _MonthGrid(month: month, moods: moods, today: today, onDay: openDay),
          const SizedBox(height: 14),
          const _Legend(),
          if ((summary, share) case (final summary?, final share?)) ...[
            const SizedBox(height: 18),
            _MonthSummary(summary: summary, sharePaise: share),
          ],
        ],
      ),
    );
  }
}

class _SetBudget extends StatelessWidget {
  const _SetBudget();

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      key: const ValueKey('calendar-set-budget'),
      color: AppColors.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              PennyMascot(size: 56, bob: false),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Give your everyday categories a budget and every day '
                  'gets my mood.',
                  style: AppText.h3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BrutalButton(
            label: 'Set a budget',
            icon: Icons.savings_outlined,
            expand: true,
            onPressed: () => context.push('/budget'),
          ),
        ],
      ),
    );
  }
}

/// The month as weeks, starting on the phone's first day of the week.
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.moods,
    required this.today,
    required this.onDay,
  });

  final DateTime month;
  final Map<int, PennyMood> moods;
  final DateTime today;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final local = MaterialLocalizations.of(context);
    final firstWeekday = local.firstDayOfWeekIndex; // 0 is Sunday.
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // DateTime.weekday runs Monday 1 to Sunday 7.
    final lead = (month.weekday % 7 - firstWeekday) % 7;
    final cells = <int?>[
      for (var i = 0; i < lead; i++) null,
      for (var day = 1; day <= daysInMonth; day++) day,
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    Widget row(List<Widget> children) =>
        Row(children: [for (final child in children) Expanded(child: child)]);

    return Column(
      children: [
        row([
          for (var i = 0; i < 7; i++)
            Center(
              child: ExcludeSemantics(
                child: Text(
                  local.narrowWeekdays[(firstWeekday + i) % 7],
                  style: AppText.label,
                ),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        for (var week = 0; week < cells.length; week += 7)
          row([
            for (final day in cells.sublist(week, week + 7))
              Padding(
                padding: const EdgeInsets.all(3),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: day == null
                      ? const SizedBox.shrink()
                      : _DayCell(
                          date: DateTime(month.year, month.month, day),
                          mood: moods[day],
                          today: today,
                          onTap: onDay,
                        ),
                ),
              ),
          ]),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.mood,
    required this.today,
    required this.onTap,
  });

  final DateTime date;
  final PennyMood? mood;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final mood = this.mood;
    final future = date.isAfter(today);
    final isToday = date == today;
    final label = [
      DateFormat('d MMMM').format(date),
      if (isToday) 'today',
      ?mood?.label,
    ].join(', ');

    return Semantics(
      button: !future,
      label: label,
      excludeSemantics: true,
      child: PressableArea(
        key: ValueKey('day-${date.day}'),
        pressedScale: 0.9,
        radius: 12,
        onTap: future ? null : () => onTap(date),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: future ? Colors.transparent : mood?.color ?? AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: future ? AppColors.hairline : AppColors.ink,
              width: isToday ? 3 : 1.5,
            ),
          ),
          // A day with a mood shows Penny's face, its date tucked in the
          // corner; any other day just its date.
          child: mood == null
              ? Center(
                  child: Text(
                    '${date.day}',
                    style: future
                        ? AppText.label.copyWith(color: AppColors.inkMuted)
                        : AppText.label,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      Positioned(
                        left: 5,
                        top: 2,
                        child: Text(
                          '${date.day}',
                          textScaler: TextScaler.noScaling,
                          style: AppText.small.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            height: 1.2,
                          ),
                        ),
                      ),
                      Align(
                        alignment: const Alignment(0, 0.6),
                        child: PennyFace(mood: mood, size: box.maxWidth * 0.72),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// How the month went, in one card: its average day against the share,
/// which sets the month's face, how many days had each face, and each
/// everyday category over or near its budget.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.summary, required this.sharePaise});

  final MonthMood summary;
  final int sharePaise;

  static const _lines = {
    PennyMood.happy: 'Your average day is within your share. Keep it up!',
    PennyMood.worried: 'Your average day is a little over your share.',
    PennyMood.sad:
        "Your average day is well over your share. Let's plan a "
        'fix!',
  };

  @override
  Widget build(BuildContext context) {
    final mood = summary.mood;
    final counts = summary.counts;
    String count(PennyMood mood, String one, String many) =>
        switch (counts[mood] ?? 0) {
          0 => '',
          1 => '1 $one',
          final n => '$n $many',
        };
    final tally = [
      count(PennyMood.happy, 'happy', 'happy'),
      count(PennyMood.worried, 'worried', 'worried'),
      count(PennyMood.sad, 'sad', 'sad'),
      count(PennyMood.celebrating, 'goal day', 'goal days'),
    ].where((part) => part.isNotEmpty).join(' · ');
    final days = summary.days == 1 ? '1 day' : '${summary.days} days';

    return BrutalCard(
      key: const ValueKey('month-summary'),
      color: mood.color,
      child: Row(
        children: [
          PennyMascot(mood: mood, size: 72),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monthly mood', style: AppText.label),
                Text(mood.label, style: AppText.h2),
                Text(_lines[mood] ?? mood.line, style: AppText.body),
                const SizedBox(height: 8),
                Text(
                  'Average day: ${formatPaise(summary.averagePaise)} of your '
                  '${formatPaise(sharePaise)} share',
                  key: const ValueKey('month-average'),
                  style: AppText.bodyStrong,
                ),
                Text(
                  '${formatPaise(summary.spentPaise)} over $days',
                  key: const ValueKey('month-spent'),
                  style: AppText.small.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  tally,
                  key: const ValueKey('month-tally'),
                  style: AppText.small.copyWith(color: AppColors.ink),
                ),
                for (final (i, note) in summary.categoryNotes.indexed)
                  Text(
                    note,
                    key: ValueKey('month-category-$i'),
                    style: AppText.small.copyWith(color: AppColors.ink),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  static const _keys = [
    (PennyMood.happy, 'At or under your share'),
    (PennyMood.worried, 'Up to 1.5 times it'),
    (PennyMood.sad, 'More than that'),
    (PennyMood.celebrating, 'A goal reached'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            for (final (mood, text) in _keys)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: mood.color,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(text, style: AppText.small),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Each day goes by what you spent that day. The month goes by your '
          "average day. Home shows today's face.",
          style: AppText.small,
        ),
      ],
    );
  }
}
