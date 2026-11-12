import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/account.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/sync/sync_controller.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/icon_badge.dart';

/// Backing up with Google, in Settings: sign in, see how the backup stands,
/// sync now, sign out, or delete the account.
class AccountCard extends ConsumerStatefulWidget {
  const AccountCard({super.key});

  @override
  ConsumerState<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<AccountCard> {
  var _busy = false;

  /// What went wrong last time, in words.
  String? _problem;

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await work();
    } on AccountException catch (error) {
      _problem = error.failure == AccountFailure.offline
          ? "Couldn't reach Penny's server. Check your internet and try "
                'again.'
          : "That didn't work just now. Try again in a bit.";
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(AccountService service) async {
    var clear = false;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Delete your account?', style: AppText.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your backup is deleted for good. This phone keeps its '
                'entries unless you tick below.',
                style: AppText.body,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const ValueKey('delete-clear-phone'),
                value: clear,
                onChanged: (on) => setDialog(() => clear = on ?? false),
                title: const Text(
                  'Also clear this phone',
                  style: AppText.bodyStrong,
                ),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it', style: AppText.bodyStrong),
            ),
            TextButton(
              key: const ValueKey('delete-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Delete',
                style: AppText.bodyStrong.copyWith(color: AppColors.negative),
              ),
            ),
          ],
        ),
      ),
    );
    if (sure != true) return;
    await _run(() async {
      await service.deleteAccount();
      if (clear) await ref.read(appDatabaseProvider).wipe();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(accountServiceProvider);
    final account = ref.watch(accountProvider).value;
    final sync = ref.watch(syncControllerProvider);
    final demo = ref.watch(demoModeProvider);
    final problem = _problem;

    return BrutalCard(
      key: const ValueKey('account-card'),
      color: account == null ? AppColors.white : AppColors.mint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(
                icon: Icons.cloud_outlined,
                color: account == null ? AppColors.yellow : AppColors.white,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account == null ? 'Back up with Google' : 'Backed up',
                  style: AppText.h3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (account == null) ...[
            const Text(
              'Keep a copy of your entries, budgets, goals, My needs and '
              'note in your account, and bring them to a new phone. SMS, '
              "the chat and Penny's reports stay on this phone.",
              style: AppText.body,
            ),
            const SizedBox(height: 12),
            if (service != null && service.canSignIn)
              BrutalButton(
                key: const ValueKey('google-sign-in'),
                label: 'Sign in with Google',
                icon: Icons.login_rounded,
                expand: true,
                onPressed: _busy
                    ? null
                    : () => _run(() => service.signInWithGoogle()),
              )
            else
              const Text(
                "Backup isn't set up in this build.",
                style: AppText.bodyMuted,
              ),
          ] else ...[
            Text(
              account.email ?? 'Signed in with Google',
              style: AppText.bodyStrong,
            ),
            Text(
              _statusLine(sync, DateTime.now()),
              key: const ValueKey('sync-status'),
              style: AppText.body,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: BrutalButton(
                    key: const ValueKey('sync-now'),
                    label: 'Sync now',
                    icon: Icons.sync_rounded,
                    expand: true,
                    onPressed: _busy || demo || sync.phase == SyncPhase.syncing
                        ? null
                        : ref.read(syncControllerProvider.notifier).syncNow,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BrutalButton(
                    key: const ValueKey('sign-out'),
                    label: 'Sign out',
                    icon: Icons.logout_rounded,
                    color: AppColors.white,
                    expand: true,
                    onPressed: _busy || service == null
                        ? null
                        : () => _run(service.signOut),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (service != null && !demo)
              TextButton(
                key: const ValueKey('delete-account'),
                onPressed: _busy ? null : () => _delete(service),
                child: Text(
                  'Delete account',
                  style: AppText.bodyStrong.copyWith(color: AppColors.negative),
                ),
              ),
          ],
          if (problem != null) ...[
            const SizedBox(height: 8),
            Text(
              problem,
              key: const ValueKey('account-problem'),
              style: AppText.bodyStrong,
            ),
          ],
        ],
      ),
    );
  }
}

/// How the backup stands, in a line.
String _statusLine(SyncStatus sync, DateTime now) => switch (sync.phase) {
  SyncPhase.paused => 'Paused while demo data is on.',
  SyncPhase.syncing => 'Syncing…',
  SyncPhase.offline =>
    "Waiting for internet. It syncs when you're back online.",
  SyncPhase.failed => "Couldn't sync. Tap Sync now to try again.",
  SyncPhase.synced || SyncPhase.off => switch (sync.lastSynced) {
    null => 'Not synced yet.',
    final at => 'Synced ${_ago(at, now)}',
  },
};

/// "just now", "5 min ago", "3 h ago", or the day.
String _ago(DateTime at, DateTime now) {
  final gone = now.difference(at);
  if (gone.inMinutes < 1) return 'just now';
  if (gone.inMinutes < 60) return '${gone.inMinutes} min ago';
  if (gone.inHours < 24) return '${gone.inHours} h ago';
  return 'on ${DateFormat('d MMM').format(at)}';
}
