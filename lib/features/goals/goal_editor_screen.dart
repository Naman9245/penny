import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/goal_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/widgets/amount_sheet.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/page_header.dart';

/// Makes a new goal, or changes [goalId]: what it's for, how much, and by
/// when.
class GoalEditorScreen extends ConsumerStatefulWidget {
  const GoalEditorScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  final _title = TextEditingController();
  int? _targetPaise;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final goal = ref
        .read(goalsProvider)
        .value
        ?.where((g) => g.id == widget.goalId)
        .firstOrNull;
    if (goal != null) {
      _title.text = goal.title;
      _targetPaise = goal.targetPaise;
      _deadline = goal.deadline;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime get _tomorrow =>
      dayStart(DateTime.now()).add(const Duration(days: 1));

  bool get _ready {
    final deadline = _deadline;
    return _title.text.trim().isNotEmpty &&
        (_targetPaise ?? 0) > 0 &&
        deadline != null &&
        !deadline.isBefore(_tomorrow);
  }

  Future<void> _pickTarget() async {
    final paise = await showAmountSheet(
      context,
      title: 'Target',
      hint: 'How much it takes.',
      initialPaise: _targetPaise,
    );
    if (paise != null) setState(() => _targetPaise = paise > 0 ? paise : null);
  }

  Future<void> _pickDeadline() async {
    final first = _tomorrow;
    final deadline = _deadline;
    final picked = await showDatePicker(
      context: context,
      initialDate: deadline != null && !deadline.isBefore(first)
          ? deadline
          : first.add(const Duration(days: 90)),
      firstDate: first,
      lastDate: DateTime(first.year + 10, first.month, first.day),
      helpText: 'Reach it by',
    );
    if (picked != null) setState(() => _deadline = dayStart(picked));
  }

  Future<void> _save() async {
    if (!_ready) return;
    final repo = ref.read(goalRepositoryProvider);
    final id = widget.goalId;
    if (id == null) {
      final newId = await repo.add(
        title: _title.text,
        targetPaise: _targetPaise!,
        deadline: _deadline!,
      );
      if (mounted) context.pushReplacement('/goals/$newId');
    } else {
      await repo.update(
        id,
        title: _title.text,
        targetPaise: _targetPaise!,
        deadline: _deadline!,
      );
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = _targetPaise;
    final deadline = _deadline;
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
      borderSide: BorderSide(color: AppColors.ink, width: 2.5),
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            PageHeader(
              title: widget.goalId == null ? 'New goal' : 'Edit goal',
              subtitle: "What you're saving for, how much, and by when.",
            ),
            const SizedBox(height: 22),
            const Text("What you're saving for", style: AppText.label),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('goal-title'),
              controller: _title,
              maxLength: GoalRepository.maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Like a Delhi trip',
                filled: true,
                fillColor: AppColors.white,
                border: border,
                enabledBorder: border,
                focusedBorder: border,
              ),
            ),
            const SizedBox(height: 12),
            _Choice(
              key: const ValueKey('goal-target'),
              label: 'Target',
              value: target == null ? 'Set an amount' : formatPaise(target),
              onTap: _pickTarget,
            ),
            const SizedBox(height: 14),
            _Choice(
              key: const ValueKey('goal-deadline'),
              label: 'Reach it by',
              value: deadline == null
                  ? 'Pick a date'
                  : DateFormat('d MMMM y').format(deadline),
              onTap: _pickDeadline,
            ),
            if (deadline != null && deadline.isBefore(_tomorrow)) ...[
              const SizedBox(height: 8),
              const Text(
                'That date has passed. Pick a new one.',
                style: AppText.small,
              ),
            ],
            const SizedBox(height: 24),
            BrutalButton(
              key: const ValueKey('save-goal'),
              label: 'Save goal',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _ready ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tappable card that shows one choice and opens its picker.
class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.small),
                Text(value, style: AppText.h3),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
        ],
      ),
    );
  }
}
