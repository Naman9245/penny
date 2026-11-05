import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/demo_data.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/settings/account_card.dart';
import 'package:penny/features/settings/notifications_card.dart';
import 'package:penny/services/csv_export.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';

/// Penny's settings, in a bottom sheet: backing up with Google, demo data
/// to try every part of the app on, and the welcome again.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the whole app, nav bar and Add button too, not just the tab.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (context) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  /// While the demo is switching or resetting.
  bool _busy = false;

  /// The sample SMS copied last, which says so.
  int? _copied;

  Future<void> _run(Future<void> Function() work) async {
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Starts the demo again from fresh, dated from today. Only while it's on,
  /// and resetDemoData refuses any database but the demo's anyway.
  Future<void> _reset() async {
    if (!ref.read(demoModeProvider)) return;
    await resetDemoData(ref.read(appDatabaseProvider), DateTime.now());
  }

  /// Every entry here as a CSV, to the share menu.
  Future<void> _export() async {
    final txns = await ref.read(txnRepositoryProvider).everything();
    final name = exportFileName(
      ref.read(todayProvider),
      demo: ref.read(demoModeProvider),
    );
    await ref.read(shareFileProvider)(name, csvBytes(entriesCsv(txns)));
  }

  Future<void> _copy(int index, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = index);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoModeProvider);
    final notifier = ref.read(demoModeProvider.notifier);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Settings', style: AppText.h2),
          const SizedBox(height: 16),
          const AccountCard(),
          const SizedBox(height: 16),
          const NotificationsCard(),
          const SizedBox(height: 16),
          BrutalCard(
            color: demo ? AppColors.sky : AppColors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Demo data', style: AppText.h3)),
                    Switch(
                      key: const ValueKey('demo-switch'),
                      value: demo,
                      onChanged: _busy
                          ? null
                          : (on) => _run(() => notifier.set(on)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  demo
                      ? "You're looking at four months of made-up money. Ask "
                            'Penny, the chat and plans use it too, and count '
                            'towards your daily limits as usual.'
                      : 'Try every part of Penny on four months of made-up '
                            'money.',
                  style: AppText.body,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your own entries stay safe, and come back when you turn '
                  'this off.',
                  style: AppText.bodyStrong,
                ),
              ],
            ),
          ),
          if (demo) ...[
            const SizedBox(height: 12),
            BrutalButton(
              key: const ValueKey('demo-reset'),
              label: 'Reset demo data',
              icon: Icons.restart_alt_rounded,
              color: AppColors.white,
              expand: true,
              onPressed: _busy ? null : () => _run(_reset),
            ),
            const SizedBox(height: 6),
            const Text(
              'Starts the demo again from today, undoing your changes to it.',
              style: AppText.small,
            ),
            const SizedBox(height: 20),
            const Text('Sample SMS', style: AppText.h3),
            const SizedBox(height: 4),
            const Text(
              'Copy one, then tap Add and Paste SMS. It goes into the demo.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 10),
            for (final (i, sms) in demoSms(DateTime.now()).indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              BrutalCard(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(sms.label, style: AppText.bodyStrong),
                          const SizedBox(height: 2),
                          Text(
                            sms.text.replaceAll('\n', ' '),
                            style: AppText.small,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    BrutalChip(
                      key: ValueKey('sms-copy-$i'),
                      label: _copied == i ? 'Copied' : 'Copy',
                      icon: _copied == i
                          ? Icons.check_rounded
                          : Icons.copy_rounded,
                      selected: _copied == i,
                      selectedColor: AppColors.mint,
                      onTap: () => _copy(i, sms.text),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          BrutalButton(
            key: const ValueKey('export-entries'),
            label: demo ? 'Export demo entries' : 'Export entries',
            icon: Icons.ios_share_rounded,
            color: AppColors.white,
            expand: true,
            onPressed: _busy ? null : () => _run(_export),
          ),
          const SizedBox(height: 6),
          const Text(
            'Every entry as a spreadsheet file, through the share menu. It '
            'holds your places and amounts, so send it only where you mean '
            'to.',
            style: AppText.small,
          ),
          const SizedBox(height: 12),
          BrutalButton(
            key: const ValueKey('show-welcome'),
            label: 'Show the welcome again',
            icon: Icons.waving_hand_outlined,
            color: AppColors.white,
            expand: true,
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.pop(context);
              router.push('/welcome');
            },
          ),
        ],
      ),
    );
  }
}
