import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_pill.dart';

/// "What Penny read", newest first.
final captureLogProvider = StreamProvider.autoDispose<List<CaptureLogEntry>>(
  (ref) => ref.watch(prefsRepositoryProvider).watchCaptureLog(),
);

/// Settings' "Read payment notifications": whether Penny may, the way to
/// allow it on Android's own page, what happens to a payment she reads, and
/// what she read lately.
class NotificationsCard extends ConsumerStatefulWidget {
  const NotificationsCard({super.key});

  @override
  ConsumerState<NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends ConsumerState<NotificationsCard>
    with WidgetsBindingObserver {
  /// How many of "What Penny read" show before Show all.
  static const _shortLog = 5;

  var _showAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android's pages: ask again what's allowed now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
        ..invalidate(notificationAccessProvider)
        ..invalidate(pennyNotifiesProvider);
    }
  }

  /// Android asks whether Penny may send notifications, then its
  /// Notification access page opens.
  Future<void> _turnOn() async {
    final inbox = ref.read(notificationInboxProvider);
    await inbox.askToNotify(orSettings: false);
    await inbox.openSettings();
  }

  Future<void> _allowNotifications() async {
    await ref.read(notificationInboxProvider).askToNotify();
    ref.invalidate(pennyNotifiesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(notificationAccessProvider).value ?? false;
    // Taken as yes until Android says, so the card doesn't flicker.
    final notifies = ref.watch(pennyNotifiesProvider).value ?? true;
    final log = ref.watch(captureLogProvider).value ?? const [];
    final today = ref.watch(todayProvider);
    final mode = ref.watch(captureModeProvider);
    final setMode = ref.read(captureModeProvider.notifier).set;
    final shown = _showAll ? log : log.take(_shortLog);
    return BrutalCard(
      key: const ValueKey('notifications-card'),
      color: allowed ? AppColors.mint : AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Read payment notifications', style: AppText.h3),
              ),
              BrutalPill(
                key: const ValueKey('notifications-status'),
                label: allowed ? 'On' : 'Off',
                color: allowed ? AppColors.white : AppColors.cream,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            allowed
                ? 'Penny reads payments from your SMS app, GPay, PhonePe and '
                      "Paytm, so you don't have to type them."
                : 'Let Penny read payments from your SMS app, GPay, PhonePe '
                      "and Paytm, so you don't have to type them.",
            style: AppText.body,
          ),
          const SizedBox(height: 10),
          BrutalButton(
            key: const ValueKey('notifications-settings'),
            label: allowed ? 'Notification access' : 'Turn on',
            icon: allowed
                ? Icons.settings_outlined
                : Icons.notifications_active_outlined,
            color: allowed ? AppColors.white : AppColors.yellow,
            expand: true,
            onPressed: allowed
                ? ref.read(notificationInboxProvider).openSettings
                : _turnOn,
          ),
          const SizedBox(height: 4),
          Text(
            allowed
                ? "You can turn it off on Android's Notification access page."
                : 'Android asks whether Penny may send you notifications, '
                      'then to allow her on its Notification access page.',
            style: AppText.small,
          ),
          if (allowed && !notifies) ...[
            const SizedBox(height: 12),
            BrutalButton(
              key: const ValueKey('notifications-allow'),
              label: 'Allow notifications',
              icon: Icons.notifications_outlined,
              color: AppColors.yellow,
              expand: true,
              onPressed: _allowNotifications,
            ),
            const SizedBox(height: 4),
            const Text(
              "Penny's own notifications are off, so she can't tell you when "
              'she reads a payment.',
              style: AppText.small,
            ),
          ],
          const SizedBox(height: 14),
          const Text('When Penny reads a payment', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalChip(
                key: const ValueKey('capture-check'),
                label: 'Wait for me to check',
                selected: mode == CaptureMode.check,
                onTap: () => setMode(CaptureMode.check),
              ),
              BrutalChip(
                key: const ValueKey('capture-save'),
                label: 'Save straight away',
                selected: mode == CaptureMode.save,
                onTap: () => setMode(CaptureMode.save),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mode == CaptureMode.check
                ? 'They wait on Home for you to add or skip.'
                : "They're saved as soon as Penny reads them. Any that may "
                      'already be logged, or need a category, still wait for '
                      'you on Home.',
            style: AppText.small.copyWith(color: AppColors.ink),
          ),
          if (allowed || log.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('What Penny read', style: AppText.label),
            const SizedBox(height: 6),
            if (log.isEmpty)
              const Text(
                'Nothing yet. The last 20 notifications Penny looks at show '
                'here, with what she did with each.',
                key: ValueKey('read-none'),
                style: AppText.small,
              )
            else ...[
              for (final (i, entry) in shown.indexed)
                Padding(
                  key: ValueKey('read-$i'),
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: _LogLine(entry: entry, today: today),
                ),
              if (log.length > _shortLog)
                TextButton(
                  key: const ValueKey('read-all'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.ink,
                    textStyle: AppText.label,
                  ),
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? 'Show fewer' : 'Show all ${log.length}'),
                ),
            ],
          ],
          const SizedBox(height: 10),
          const Text(
            'Only those apps, and only what looks like a payment. It stays on '
            "this phone, and people's names never reach the AI. What Penny "
            'read keeps what she did with each, never the message.',
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

/// One of "What Penny read": "2:31 PM · SMS · Waiting: −₹250 · Swiggy".
class _LogLine extends StatelessWidget {
  const _LogLine({required this.entry, required this.today});

  final CaptureLogEntry entry;
  final DateTime today;

  static const _outcomes = {
    'waiting': 'Waiting',
    'saved': 'Saved',
    'letGo': 'Let go',
  };

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(entry.at);
    final when = dayStart(entry.at) == today
        ? time
        : '${DateFormat('d MMM').format(entry.at)}, $time';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$when · ${appName(entry.app)} · '),
          TextSpan(
            text: '${_outcomes[entry.outcome] ?? entry.outcome}: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: entry.what),
        ],
      ),
      style: AppText.small.copyWith(color: AppColors.ink),
    );
  }
}
