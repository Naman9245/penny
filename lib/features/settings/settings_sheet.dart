import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/account.dart';
import 'package:penny/data/demo_data.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/settings/account_card.dart';
import 'package:penny/features/settings/lock_card.dart';
import 'package:penny/features/settings/notifications_card.dart';
import 'package:penny/services/app_lock.dart';
import 'package:penny/services/csv_export.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/icon_badge.dart';
import 'package:penny/widgets/page_header.dart';
import 'package:penny/widgets/pressable_area.dart';

/// Penny's settings, in a bottom sheet: a short list, each row opening its
/// own page, then exporting and the welcome again.
Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the whole app, nav bar and Add button too, not just the tab.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

/// Opens the Demo data page straight away, as Home's demo banner does.
Future<void> showDemoSettings(BuildContext context) =>
    _pushPage(context, const _DemoPage());

Future<void> _pushPage(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true).push(_settingsRoute(page));

/// A Settings page's route, sliding in from the side. Not opaque, so Home
/// and the list stay awake beneath it, as under the sheet: a page that
/// switches the demo swaps the money they show, which they must take in as
/// it happens.
Route<void> _settingsRoute(Widget page) => PageRouteBuilder<void>(
  opaque: false,
  pageBuilder: (context, animation, secondaryAnimation) =>
      _SettingsPage(child: page),
  transitionsBuilder: (context, animation, secondaryAnimation, child) =>
      SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: child,
      ),
);

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  /// While the export is being made.
  bool _exporting = false;

  /// Opens [page] over the list; Back comes back to it.
  Future<void> _open(Widget page) => _pushPage(context, page);

  /// Every entry here as a CSV, to the share menu.
  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final txns = await ref.read(txnRepositoryProvider).everything();
      final name = exportFileName(
        ref.read(todayProvider),
        demo: ref.read(demoModeProvider),
      );
      await ref.read(shareFileProvider)(name, csvBytes(entriesCsv(txns)));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoModeProvider);
    final email = ref.watch(accountProvider).value?.email;
    final signedIn = ref.watch(accountProvider).value != null;
    final locked = ref.watch(appLockProvider);
    final reading = ref.watch(notificationAccessProvider).value ?? false;
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
          BrutalCard(
            padding: EdgeInsets.zero,
            clipChild: true,
            child: Column(
              children: [
                _SettingsRow(
                  key: const ValueKey('settings-backup'),
                  icon: Icons.cloud_outlined,
                  color: AppColors.yellow,
                  title: 'Back up with Google',
                  status: signedIn ? email ?? 'On' : 'Off',
                  onTap: () => _open(const AccountCard()),
                ),
                const RowDivider(),
                _SettingsRow(
                  key: const ValueKey('settings-lock'),
                  icon: Icons.fingerprint_rounded,
                  color: AppColors.lavender,
                  title: 'Lock Penny',
                  status: locked ? 'On' : 'Off',
                  onTap: () => _open(const LockCard()),
                ),
                const RowDivider(),
                _SettingsRow(
                  key: const ValueKey('settings-reading'),
                  icon: Icons.notifications_active_outlined,
                  color: AppColors.sky,
                  title: 'Reading payments',
                  status: reading ? 'On' : 'Off',
                  onTap: () => _open(const NotificationsCard()),
                ),
                const RowDivider(),
                _SettingsRow(
                  key: const ValueKey('settings-demo'),
                  icon: Icons.science_outlined,
                  color: AppColors.mint,
                  title: 'Demo data',
                  status: demo ? 'On' : 'Off',
                  onTap: () => _open(const _DemoPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BrutalCard(
            padding: EdgeInsets.zero,
            clipChild: true,
            child: Column(
              children: [
                _SettingsRow(
                  key: const ValueKey('export-entries'),
                  icon: Icons.ios_share_rounded,
                  color: AppColors.white,
                  title: demo ? 'Export demo entries' : 'Export entries',
                  status: _exporting ? 'Making the file…' : null,
                  onTap: _exporting ? null : _export,
                  opens: false,
                ),
                const RowDivider(),
                _SettingsRow(
                  key: const ValueKey('show-welcome'),
                  icon: Icons.waving_hand_outlined,
                  color: AppColors.white,
                  title: 'Show the welcome again',
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.pop(context);
                    router.push('/welcome');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'An export is every entry as a spreadsheet file, through the share '
            'menu. It holds your places and amounts, so send it only where you '
            'mean to.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

/// One row of Settings: what it is, how it stands, and that it opens.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.status,
    this.opens = true,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? status;
  final VoidCallback? onTap;

  /// Whether it opens a page, which the chevron says.
  final bool opens;

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return Semantics(
      button: true,
      child: PressableArea(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              IconBadge(icon: icon, color: color, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyStrong),
                    if (status != null)
                      Text(
                        status,
                        style: AppText.small,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (opens)
                const Icon(Icons.chevron_right_rounded, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// A page of Settings, over everything, with Back to the list.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Its own messenger, so what it says shows on it, not on Home beneath.
    return ScaffoldMessenger(
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              PageHeader(
                title: 'Settings',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Demo data: made-up money to try every part of Penny on, starting it
/// again, and sample SMS to paste.
class _DemoPage extends ConsumerStatefulWidget {
  const _DemoPage();

  @override
  ConsumerState<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends ConsumerState<_DemoPage> {
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

  Future<void> _copy(int index, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = index);
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(demoModeProvider);
    final notifier = ref.read(demoModeProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrutalCard(
          color: demo ? AppColors.sky : AppColors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(
                    icon: Icons.science_outlined,
                    color: AppColors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
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
      ],
    );
  }
}
