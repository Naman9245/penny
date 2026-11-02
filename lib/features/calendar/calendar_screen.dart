import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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

/// Every day of a month coloured by Penny's mood that day, so spending
/// patterns show at a glance. Tap a day for what was spent.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _month = monthStart(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final budget = ref.watch(budgetProvider).value ?? Budget.none;
    final txns = ref.watch(monthTxnsProvider(_month)).value ?? const <Txn>[];
    final everyday = budget.everydayPaise;
    final share = everyday == null ? null : dailySharePaise(everyday, _month);
    final moods = dayMoods(
      budget: budget,
      monthTxns: txns,
      month: _month,
      now: now,
      firstEntry: ref.watch(firstEntryProvider).value,
    );

    void openDay(DateTime date) => showDaySheet(
      context,
      date: date,
      mood: moods[date.day],
      entries: [
        for (final txn in txns)
          if (dayStart(txn.occurredAt) == date) txn,
      ],
      sharePaise: share,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        // Room at the bottom so the Add button never hides the legend.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          const Text('Mood calendar', style: AppText.h1),
          const SizedBox(height: 14),
          MonthSwitcher(
            month: _month,
            onChanged: (month) => setState(() => _month = month),
          ),
          const SizedBox(height: 16),
          if (share == null)
            const _SetBudget()
          else
            Text(
              'Your share each day: ${formatPaise(share)}',
              style: AppText.bodyStrong,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 14),
          _MonthGrid(
            month: _month,
            moods: moods,
            today: dayStart(now),
            onDay: openDay,
          ),
          const SizedBox(height: 18),
          const _Legend(),
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
                  'Set a monthly budget and every day gets my mood.',
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
      child: GestureDetector(
        key: ValueKey('day-${date.day}'),
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
          child: Center(
            child: Text(
              '${date.day}',
              style: future
                  ? AppText.label.copyWith(color: AppColors.inkMuted)
                  : AppText.label,
            ),
          ),
        ),
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
    return Wrap(
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
    );
  }
}
