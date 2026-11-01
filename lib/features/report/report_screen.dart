import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/report/report_controller.dart';
import 'package:penny/features/report/sent_sheet.dart';
import 'package:penny/models/category.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/models/your_rules.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/insight_math.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/money_text.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/tag_split_bar.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

/// Penny's look at one month: habits worth cutting and what cutting them
/// would have saved, the necessary-or-wasteful split, and how steady the
/// income is. Penny sorts and explains; every number here is worked out on
/// the phone from the entries as they are now.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, required this.month});

  final DateTime month;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  /// Whether this visit has decided to look again yet. Only once per visit.
  bool _checkedFreshness = false;

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    final request = ref.watch(insightRequestProvider(month)).value;
    final saved = ref.watch(insightProvider(month));
    final ask = ref.watch(askPennyProvider(month));
    final setUp = ref.watch(aiClientProvider).isSetUp;
    final report = saved.value;

    void askPenny() {
      if (request != null) {
        ref.read(askPennyProvider(month).notifier).ask(request);
      }
    }

    // A month Penny has looked at before, whose entries changed since: she
    // looks again by herself when the report opens.
    if (!_checkedFreshness && request != null && saved.hasValue) {
      _checkedFreshness = true;
      final stale = report != null && report.inputHash != request.inputHash;
      if (stale && setUp && request.canAsk && !ask.asking) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) askPenny();
        });
      }
    }

    final failure = ask.asking ? null : ask.failure;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Header(month: month),
            const SizedBox(height: 18),
            if (request == null || (saved.isLoading && !saved.hasValue))
              const SizedBox.shrink()
            else if (report == null) ...[
              if (ask.asking)
                const _Thinking()
              else
                _Intro(
                  month: month,
                  request: request,
                  setUp: setUp,
                  onAsk: askPenny,
                ),
              if (failure != null) ...[
                const SizedBox(height: 16),
                _Problem(failure: failure, onRetry: askPenny),
              ],
            ] else
              _Report(
                month: month,
                report: report,
                request: request,
                ask: ask,
                canAsk: setUp && request.canAsk,
                onRefresh: askPenny,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BrutalIconButton(
          icon: Icons.arrow_back_rounded,
          semanticLabel: 'Back',
          onPressed: () => context.pop(),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wasteful report', style: AppText.h2),
              Text(monthLabel(month), style: AppText.bodyMuted),
            ],
          ),
        ),
      ],
    );
  }
}

/// Before Penny has looked: what she'll do, and what she'll be sent.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.month,
    required this.request,
    required this.setUp,
    required this.onAsk,
  });

  final DateTime month;
  final InsightRequest request;
  final bool setUp;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final blocker = !setUp
        ? "Penny's AI isn't set up in this build."
        : !request.canAsk
        ? 'Add at least $minSpendsToAsk spends this month first.'
        : null;
    return BrutalCard(
      color: AppColors.lavender,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PennyMascot(size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Want Penny to look at ${DateFormat('MMMM').format(month)}?',
                  style: AppText.h2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            "She'll sort the month's spends into necessary and wasteful, and "
            'spot habits worth cutting.',
            style: AppText.body,
          ),
          const SizedBox(height: 8),
          const Text(
            "Penny sends this month's totals per shop. Never your SMS, and "
            'never the names of people you pay.',
            style: AppText.small,
          ),
          if (blocker != null) ...[
            const SizedBox(height: 12),
            Text(blocker, style: AppText.bodyStrong),
          ],
          const SizedBox(height: 16),
          BrutalButton(
            key: const ValueKey('ask-penny'),
            label: 'Ask Penny',
            icon: Icons.auto_awesome_rounded,
            expand: true,
            onPressed: blocker == null ? onAsk : null,
          ),
          const SizedBox(height: 12),
          Center(child: _SeeWhatPennySends(request: request)),
        ],
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();

  @override
  Widget build(BuildContext context) {
    return const BrutalCard(
      key: ValueKey('penny-thinking'),
      color: AppColors.lavender,
      padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PennyMascot(size: 72),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Penny is looking at your month…',
                  style: AppText.h3,
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          _Waiting(),
        ],
      ),
    );
  }
}

/// A bar that keeps moving while Penny thinks, so a long wait doesn't look
/// stuck. It holds still when the system asks for less motion.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(kPillRadius),
            border: Border.all(color: AppColors.ink, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(kPillRadius),
            child: MediaQuery.disableAnimationsOf(context)
                ? const SizedBox.expand()
                : const LinearProgressIndicator(
                    minHeight: 10,
                    color: AppColors.ink,
                    backgroundColor: AppColors.white,
                    semanticsLabel: 'Penny is thinking',
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'This can take up to half a minute.',
          style: AppText.small.copyWith(color: AppColors.ink),
        ),
      ],
    );
  }
}

class _Problem extends StatelessWidget {
  const _Problem({required this.failure, required this.onRetry});

  final AiException failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      key: const ValueKey('ask-problem'),
      color: AppColors.yellow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PennyMascot(mood: PennyMood.worried, size: 56, bob: false),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(failure.message, style: AppText.bodyStrong),
                const SizedBox(height: 10),
                BrutalButton(
                  label: 'Try again',
                  color: AppColors.white,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The report itself. Penny's tags and words come from the saved answer;
/// every amount comes from this month's entries as they are now.
class _Report extends ConsumerWidget {
  const _Report({
    required this.month,
    required this.report,
    required this.request,
    required this.ask,
    required this.canAsk,
    required this.onRefresh,
  });

  final DateTime month;
  final SavedInsight report;
  final InsightRequest request;
  final AskState ask;
  final bool canAsk;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(monthTxnsProvider(month)).value ?? const <Txn>[];
    final rules = ref.watch(yourRulesProvider).value ?? YourRules.none;
    final habits = habitViews(txns, report, rules: rules);
    final split = splitByTag(txns, report, rules: rules);
    final stale = report.inputHash != request.inputHash;
    final failure = ask.asking ? null : ask.failure;
    final insight = report.insight;

    Future<void> keep(HabitView habit) async {
      final repo = ref.read(txnRepositoryProvider);
      final before = {for (final txn in habit.wasteful) txn.id: txn.tag};
      await repo.setTags({
        for (final txn in habit.wasteful) txn.id: TxnTag.necessary,
      });
      if (!context.mounted) return;
      showUndoSnackBar(
        context,
        message: '${habit.title} moved to necessary',
        onUndo: () => repo.setTags(before),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (stale || ask.asking) ...[
          _Stale(
            asking: ask.asking,
            onRefresh: canAsk && !ask.asking ? onRefresh : null,
          ),
          const SizedBox(height: 16),
        ],
        if (failure != null) ...[
          _Problem(failure: failure, onRetry: onRefresh),
          const SizedBox(height: 16),
        ],
        _Hero(totalPaise: totalSavingPaise(habits), month: month),
        if (insight.summary.isNotEmpty) ...[
          const SizedBox(height: 16),
          _PennySays(text: insight.summary),
        ],
        if (habits.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('Habits to cut', style: AppText.h2),
          for (final habit in habits) ...[
            const SizedBox(height: 12),
            _HabitCard(habit: habit, onKeep: () => keep(habit)),
          ],
        ],
        const SizedBox(height: 28),
        const Text('Necessary vs wasteful', style: AppText.h2),
        const SizedBox(height: 12),
        BrutalCard(
          child: Column(
            children: [
              TagSplitBar(split: split),
              const SizedBox(height: 12),
              TagSplitKey(split: split),
            ],
          ),
        ),
        if (request.income.isNotEmpty) ...[
          const SizedBox(height: 28),
          const Text('Where your money came from', style: AppText.h2),
          const SizedBox(height: 12),
          _Income(txns: txns, request: request, note: insight.incomeNote),
        ],
        const SizedBox(height: 24),
        _Footer(report: report, request: request, ask: ask),
      ],
    );
  }
}

class _Stale extends StatelessWidget {
  const _Stale({required this.asking, required this.onRefresh});

  final bool asking;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      key: const ValueKey('report-stale'),
      color: AppColors.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            asking
                ? 'Penny is looking again…'
                : "You've changed entries since Penny looked.",
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: 10),
          if (asking)
            const _Waiting()
          else
            BrutalButton(
              key: const ValueKey('refresh-report'),
              label: 'Refresh',
              icon: Icons.refresh_rounded,
              color: AppColors.white,
              onPressed: onRefresh,
            ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.totalPaise, required this.month});

  final int totalPaise;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    if (totalPaise == 0) {
      return const BrutalCard(
        key: ValueKey('report-hero'),
        color: AppColors.mint,
        child: Row(
          children: [
            PennyMascot(mood: PennyMood.celebrating, size: 64),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nothing wasteful to cut. Nice going!',
                style: AppText.h3,
              ),
            ),
          ],
        ),
      );
    }
    final over = !DateTime.now().isBefore(nextMonth(month));
    return BrutalCard(
      key: const ValueKey('report-hero'),
      color: AppColors.yellow,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Stop these and you'd have saved", style: AppText.label),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(totalPaise, style: AppText.hero),
          ),
          Text(
            over
                ? 'in ${DateFormat('MMMM').format(month)}'
                : 'so far this month',
            style: AppText.bodyStrong,
          ),
        ],
      ),
    );
  }
}

/// A line from Penny, with Penny.
class _PennySays extends StatelessWidget {
  const _PennySays({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PennyMascot(size: 44, bob: false),
        const SizedBox(width: 10),
        Expanded(
          child: BrutalCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(text, style: AppText.body),
          ),
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.onKeep});

  final HabitView habit;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final named = habit.habit.title.isNotEmpty;
    final cut = habit.habit.cut;
    return BrutalCard(
      key: ValueKey('habit-${habit.habit.groupIds.first}'),
      color: AppColors.pink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(habit.title, style: AppText.h3),
          if (named) ...[
            const SizedBox(height: 2),
            Text(
              habit.names.join(' · '),
              style: AppText.small.copyWith(color: AppColors.ink),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '${formatPaise(habit.spentPaise)} this month',
            style: AppText.bodyStrong,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Semantics(
                label: cut.label,
                excludeSemantics: true,
                child: _Pill(label: cut.short, color: AppColors.white),
              ),
              _Pill(
                label: 'Save ${formatPaise(habit.savePaise)}',
                color: AppColors.mint,
              ),
            ],
          ),
          if (habit.habit.tip.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PennyMascot(size: 30, bob: false),
                const SizedBox(width: 8),
                Expanded(child: Text(habit.habit.tip, style: AppText.body)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: BrutalChip(
              label: 'I need this',
              icon: Icons.check_rounded,
              onTap: onKeep,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(kPillRadius),
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: Text(label, style: AppText.chip),
    );
  }
}

class _Income extends StatelessWidget {
  const _Income({
    required this.txns,
    required this.request,
    required this.note,
  });

  final List<Txn> txns;
  final InsightRequest request;
  final String note;

  @override
  Widget build(BuildContext context) {
    final totals = <String, int>{};
    for (final txn in txns) {
      if (txn.type == TxnType.credit) {
        totals[txn.categoryId] =
            (totals[txn.categoryId] ?? 0) + txn.amountPaise;
      }
    }
    return BrutalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, income) in request.income.indexed) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryById(income['category']! as String).label,
                        style: AppText.bodyStrong,
                      ),
                      Text(
                        Steadiness.fromWire(income['steadiness'])?.label ?? '',
                        style: AppText.small,
                      ),
                    ],
                  ),
                ),
                MoneyText(
                  totals[income['category']] ?? 0,
                  type: TxnType.credit,
                  style: AppText.h3,
                ),
              ],
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PennyMascot(size: 30, bob: false),
                const SizedBox(width: 8),
                Expanded(child: Text(note, style: AppText.body)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.report,
    required this.request,
    required this.ask,
  });

  final SavedInsight report;
  final InsightRequest request;
  final AskState ask;

  @override
  Widget build(BuildContext context) {
    final looked = DateFormat('d MMM, h:mm a').format(report.createdAt);
    final left = ask.callsLeftToday;
    return Column(
      children: [
        Text(
          'Penny looked on $looked · ${report.model}',
          style: AppText.small,
          textAlign: TextAlign.center,
        ),
        if (left != null)
          Text(
            left == 1 ? '1 more look today' : '$left more looks today',
            style: AppText.small,
          ),
        const SizedBox(height: 12),
        _SeeWhatPennySends(request: request),
      ],
    );
  }
}

class _SeeWhatPennySends extends StatelessWidget {
  const _SeeWhatPennySends({required this.request});

  final InsightRequest request;

  @override
  Widget build(BuildContext context) {
    return BrutalChip(
      key: const ValueKey('see-what-penny-sends'),
      label: 'See what Penny sends',
      icon: Icons.visibility_outlined,
      onTap: () => showSentSheet(context, request),
    );
  }
}
