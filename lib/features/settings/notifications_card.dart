import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_pill.dart';
import 'package:penny/widgets/sliding_toggle.dart';
import 'package:penny/widgets/undo_snack_bar.dart';
import 'package:penny/widgets/icon_badge.dart';

/// "What Penny read", newest first.
final captureLogProvider = StreamProvider.autoDispose<List<CaptureLogEntry>>(
  (ref) => ref.watch(prefsRepositoryProvider).watchCaptureLog(),
);

/// Entries Penny saved twice from payments she read, kept up to date.
final readCopiesProvider = StreamProvider.autoDispose<List<ReadCopy>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db
      .customSelect('SELECT 1', readsFrom: {db.txns, db.pendingCaptures})
      .watch()
      .asyncMap((_) => findReadCopies(db));
});

/// How far back reading older bank SMS can go, in months.
const _lookBackMonths = [1, 2, 3];

/// "the last month", "the last 2 months".
String _lastMonths(int months) =>
    months == 1 ? 'the last month' : 'the last $months months';

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

  /// How far back to read older SMS, in months; while Penny reads them;
  /// and what she found, and how far back she looked.
  var _months = 1;
  var _lookingBack = false;
  ({int found, int months})? _lookedBack;

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
        ..invalidate(pennyNotifiesProvider)
        ..invalidate(smsAccessProvider);
    }
  }

  /// Android asks whether Penny may send notifications, then its
  /// Notification access page opens.
  Future<void> _turnOn() async {
    final inbox = ref.read(notificationInboxProvider);
    await inbox.askToNotify(orSettings: false);
    await inbox.openSettings();
  }

  Future<void> _allowSms() async {
    await ref.read(notificationInboxProvider).askSms();
    ref.invalidate(smsAccessProvider);
  }

  Future<void> _lookBack() async {
    final months = _months;
    setState(() => _lookingBack = true);
    final found = await lookBackAtSms(
      inbox: ref.read(notificationInboxProvider),
      intake: ref.read(captureIntakeProvider),
      days: lookBackDays(months, ref.read(todayProvider)),
    );
    if (!mounted) return;
    setState(() {
      _lookingBack = false;
      _lookedBack = (found: found, months: months);
    });
  }

  Future<void> _removeCopies(List<ReadCopy> copies) async {
    final db = ref.read(appDatabaseProvider);
    final txns = ref.read(txnRepositoryProvider);
    final moved = await removeReadCopies(db, txns, copies);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: copies.length == 1
          ? 'Took off 1 copy'
          : 'Took off ${copies.length} copies',
      onUndo: () => restoreReadCopies(db, txns, moved),
    );
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
    final readsSms = ref.watch(smsAccessProvider).value ?? false;
    final log = ref.watch(captureLogProvider).value ?? const [];
    final copies = ref.watch(readCopiesProvider).value ?? const [];
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
              const IconBadge(
                icon: Icons.notifications_active_outlined,
                color: AppColors.sky,
                size: 32,
              ),
              const SizedBox(width: 10),
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
                ? 'Penny reads payments from your SMS app, payment and wallet '
                      "apps, and investing apps, so you don't have to type them."
                : 'Let Penny read payments from your SMS app, payment and '
                      "wallet apps, and investing apps, so you don't have to "
                      'type them.',
            style: AppText.body,
          ),
          const SizedBox(height: 4),
          const Text(
            'GPay, PhonePe, Paytm, PayZapp, MobiKwik, CRED, BHIM, '
            'super.money, Groww, Kite, Upstox, INDmoney and Paytm Money.',
            key: ValueKey('notifications-apps'),
            style: AppText.small,
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
          Row(
            children: [
              const Expanded(
                child: Text('Read bank SMS too', style: AppText.label),
              ),
              if (readsSms)
                const BrutalPill(
                  key: ValueKey('sms-status'),
                  label: 'On',
                  color: AppColors.white,
                )
              else
                BrutalChip(
                  key: const ValueKey('sms-allow'),
                  label: 'Allow',
                  icon: Icons.sms_outlined,
                  onTap: _allowSms,
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "So a bank SMS is read even when its notification is missed. Only "
            'money messages from banks, wallets and investments are kept; '
            'every other SMS is passed over.',
            style: AppText.small,
          ),
          if (readsSms) ...[
            const SizedBox(height: 14),
            const Text('Read older bank SMS', style: AppText.label),
            const SizedBox(height: 4),
            const Text(
              'Pick how far back. A payment already in your entries is '
              'never added twice.',
              style: AppText.small,
            ),
            const SizedBox(height: 8),
            // Smaller, rather than cut off, on a narrow phone or at a large
            // text size.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SlidingToggle<int>(
                key: const ValueKey('sms-look-back-months'),
                options: [
                  for (final months in _lookBackMonths)
                    ToggleOption(
                      value: months,
                      label: months == 1 ? '1 month' : '$months months',
                      color: AppColors.yellow,
                    ),
                ],
                value: _months,
                onChanged: (months) => setState(() => _months = months),
              ),
            ),
            const SizedBox(height: 8),
            BrutalChip(
              key: const ValueKey('sms-look-back'),
              label: _lookingBack ? 'Reading…' : 'Read ${_lastMonths(_months)}',
              icon: Icons.history_rounded,
              onTap: _lookingBack ? null : _lookBack,
            ),
            if (_lookedBack case (:final found, :final months)) ...[
              const SizedBox(height: 4),
              Text(
                switch (found) {
                  0 => 'Nothing new in ${_lastMonths(months)}.',
                  1 =>
                    'Penny found 1 payment message from '
                        "${_lastMonths(months)}. It's on Home.",
                  _ =>
                    'Penny found $found payment messages from '
                        "${_lastMonths(months)}. They're on Home.",
                },
                key: const ValueKey('sms-looked-back'),
                style: AppText.small.copyWith(color: AppColors.ink),
              ),
            ],
          ],
          if (copies.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ReadCopies(copies: copies, onRemove: () => _removeCopies(copies)),
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
                : "They're saved as soon as Penny reads them. One you've "
                      "already typed isn't saved again, and you can change "
                      'any of them.',
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
                  child: Text(
                    _showAll ? 'Show fewer' : 'Show all ${log.length}',
                  ),
                ),
            ],
          ],
          const SizedBox(height: 10),
          const Text(
            'Only those apps, and only what looks like a payment. It stays on '
            "this phone, except one Penny's rules can't read: that goes to "
            "her AI with every name and long number hidden, so people's "
            'names never reach it. What Penny read keeps what she did with '
            'each, never the message.',
            key: ValueKey('notifications-privacy'),
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}

/// Entries Penny saved twice, each with the entry it copies, and the way to
/// take the copies off.
class _ReadCopies extends StatefulWidget {
  const _ReadCopies({required this.copies, required this.onRemove});

  final List<ReadCopy> copies;
  final VoidCallback onRemove;

  @override
  State<_ReadCopies> createState() => _ReadCopiesState();
}

class _ReadCopiesState extends State<_ReadCopies> {
  static const _short = 5;

  var _showAll = false;

  /// "−₹250 · Ramesh Kumar (People)".
  static String _entry(Txn txn) {
    final sign = txn.type == TxnType.debit ? '−' : '+';
    final kind = kindLabel(txn.type, txn.categoryId);
    final name = txn.merchant;
    return '$sign${formatPaise(txn.amountPaise)} · '
        '${name == null ? kind : '$name ($kind)'}';
  }

  @override
  Widget build(BuildContext context) {
    final copies = widget.copies;
    final shown = _showAll ? copies : copies.take(_short);
    final count = copies.length;
    return Column(
      key: const ValueKey('read-copies'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Saved twice', style: AppText.label),
        const SizedBox(height: 4),
        Text(
          count == 1
              ? 'Penny saved 1 payment twice: once as the entry you already '
                    'had, and once from what she read. Take the copy off and '
                    'it counts once.'
              : 'Penny saved $count payments twice: once as the entry you '
                    'already had, and once from what she read. Take the '
                    'copies off and each counts once.',
          style: AppText.small.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 6),
        for (final (i, (:copy, :of)) in shown.indexed)
          Padding(
            key: ValueKey('read-copy-$i'),
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text(
              '${DateFormat('d MMM').format(copy.occurredAt)}: '
              '${_entry(copy)}, a copy of ${_entry(of)}',
              style: AppText.small,
            ),
          ),
        if (count > _short)
          TextButton(
            key: const ValueKey('read-copies-all'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.ink,
              textStyle: AppText.label,
            ),
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? 'Show fewer' : 'Show all $count'),
          ),
        const SizedBox(height: 8),
        BrutalButton(
          key: const ValueKey('read-copies-remove'),
          label: count == 1 ? 'Take off 1 copy' : 'Take off $count copies',
          icon: Icons.delete_sweep_outlined,
          color: AppColors.yellow,
          expand: true,
          onPressed: widget.onRemove,
        ),
      ],
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
    'unread': "Couldn't read yet",
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
