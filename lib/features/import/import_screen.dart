import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/add_txn/add_txn_controller.dart';
import 'package:penny/features/add_txn/add_txn_screen.dart';
import 'package:penny/features/transactions/txn_tile.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/services/sms_parser.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/penny_mascot.dart';

/// Where a shared or pasted SMS lands: a pre-filled review when it's a new
/// payment, otherwise why Penny won't add it.
class ImportScreen extends ConsumerWidget {
  const ImportScreen({super.key, required this.sms});

  final SmsParse? sms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (sms) {
      final SmsTxn txn => ref.watch(txnByDedupeKeyProvider(txn.dedupeKey)).when(
            data: (existing) => existing == null
                ? AddTxnView(args: AddTxnArgs.fromSms(txn))
                : _AlreadyAdded(existing),
            loading: () => const Scaffold(body: SizedBox.shrink()),
            error: (error, stackTrace) => AddTxnView(args: AddTxnArgs.fromSms(txn)),
          ),
      SmsIgnored(:final reason) => _Outcome(
          mood: PennyMood.worried,
          title: 'Not a payment',
          message: reason.explanation,
          action: 'Add by hand',
          onAction: () => context.pushReplacement('/add'),
        ),
      null => const _Outcome(
          mood: PennyMood.neutral,
          title: 'Nothing to add',
          message: 'Share a bank SMS to Penny, or copy one and tap Paste SMS.',
        ),
    };
  }
}

class _AlreadyAdded extends StatelessWidget {
  const _AlreadyAdded(this.txn);

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final day = dayLabel(txn.occurredAt);
    final when = day == 'Today' || day == 'Yesterday' ? day.toLowerCase() : 'on $day';
    return _Outcome(
      mood: PennyMood.happy,
      title: 'Already added',
      message: 'You added this SMS $when.',
      action: 'Open it',
      onAction: () => context.pushReplacement('/txns/${txn.id}'),
      child: BrutalCard(
        padding: EdgeInsets.zero,
        clipChild: true,
        child: TxnTile(txn: txn, showDay: true),
      ),
    );
  }
}

/// Penny, a short verdict, and what to do next.
class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.mood,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
    this.child,
  });

  final PennyMood mood;
  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final child = this.child;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: BrutalIconButton(
                icon: Icons.close_rounded,
                semanticLabel: 'Close',
                onPressed: () => context.pop(),
              ),
            ),
            const SizedBox(height: 24),
            Center(child: PennyMascot(mood: mood, size: 130)),
            const SizedBox(height: 18),
            Text(title, style: AppText.h1, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: AppText.body, textAlign: TextAlign.center),
            if (child != null) ...[const SizedBox(height: 20), child],
            const SizedBox(height: 28),
            if (action != null) ...[
              BrutalButton(label: action, expand: true, onPressed: onAction),
              const SizedBox(height: 12),
            ],
            BrutalButton(
              label: 'Close',
              color: AppColors.white,
              expand: true,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}
