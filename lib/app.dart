import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/features/lock/lock_gate.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/theme/app_theme.dart';
import 'package:penny/core/utils/money.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/sync/sync_controller.dart';
import 'package:penny/services/autopay_math.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/money_kinds.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/share_inbox.dart';
import 'package:penny/services/sms_parser.dart';
import 'package:penny/widgets/undo_snack_bar.dart';

class PennyApp extends ConsumerStatefulWidget {
  const PennyApp({super.key});

  @override
  ConsumerState<PennyApp> createState() => _PennyAppState();
}

class _PennyAppState extends ConsumerState<PennyApp> {
  late final StreamSubscription<String> _shares;
  late final StreamSubscription<void> _captures;
  late final StreamSubscription<void> _openHome;
  late final StreamSubscription<void> _refreshed;
  late final AppLifecycleListener _lifecycle;
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    final inbox = ref.read(shareInboxProvider);
    _shares = inbox.shared.listen(_review);
    // Payments read from notifications: taken as Penny opens, as it comes
    // back, as more arrive while it's open, and once demo data is off.
    final notifications = ref.read(notificationInboxProvider);
    _captures = notifications.arrived.listen((_) => _takeCaptures());
    // Penny's own notification, tapped: Home has what she read.
    _openHome = notifications.openHome.listen(
      (_) => ref.read(routerProvider).go('/home'),
    );
    // Her hidden copy just read payments: show them, and take anything
    // newer.
    _refreshed = notifications.refreshed.listen((_) {
      final db = ref.read(appDatabaseProvider);
      db.markTablesUpdated([db.txns, db.pendingCaptures, db.prefs]);
      _takeCaptures();
    });
    ref.listenManual(demoModeProvider, (was, demo) {
      if (!demo) _takeCaptures();
    });
    // Autopay reminders follow every change, so Android always has the
    // next ones.
    ref.listenManual(
      autopaysProvider,
      (was, autopays) => _remind(autopays.value),
      fireImmediately: true,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _takeCaptures();
      final text = await inbox.takeLaunchShare();
      if (text != null && mounted) _review(text);
    });
    // Backup, if signed in: it syncs as the app opens, and keeps up.
    ref.read(syncControllerProvider);
    _lifecycle = AppLifecycleListener(
      onResume: () {
        // Sharing from Messages can open a second copy of Penny on top of
        // it. When this copy comes back to the front, re-read what that one
        // saved.
        final db = ref.read(appDatabaseProvider);
        db.markTablesUpdated([db.txns, db.pendingCaptures, db.prefs]);
        // The phone may have slept through midnight.
        ref.read(todayProvider.notifier).check();
        ref.read(syncControllerProvider.notifier).syncNow();
        _takeCaptures();
        _remind(ref.read(autopaysProvider).value);
      },
    );
  }

  /// Hands Android the reminders for [autopays], from now on.
  Future<void> _remind(List<Autopay>? autopays) async {
    if (autopays == null) return;
    await ref
        .read(notificationInboxProvider)
        .scheduleReminders(remindersFor(autopays, DateTime.now()));
  }

  /// Reads a shared SMS on the phone and opens its review.
  void _review(String text) {
    ref.read(routerProvider).push('/import', extra: parseSms(text));
  }

  /// Takes the payments waiting from notifications, and says what Penny
  /// read: at the bottom while she's on screen, or else in her own
  /// notification. Any saved straight away get an Undo, which holds them to
  /// be checked instead.
  Future<void> _takeCaptures() async {
    final List<CaptureRead> reads;
    try {
      // Any the listener missed while it was stopped, still showing.
      await ref.read(notificationInboxProvider).catchUp();
      reads = await ref.read(captureIntakeProvider).take();
    } on Exception {
      // They stay waiting for next time.
      return;
    }
    if (!mounted) return;
    final state = WidgetsBinding.instance.lifecycleState;
    final onScreen = state == null || state == AppLifecycleState.resumed;
    final messenger = _messenger.currentState;
    if (!onScreen || messenger == null) {
      if (noticeFor(reads) case final notice?) {
        await ref.read(notificationInboxProvider).notify(notice);
      }
      return;
    }
    final saved = [
      for (final read in reads)
        if (read.outcome == CaptureOutcome.saved) read,
    ];
    final waiting = reads.where((r) => r.outcome == CaptureOutcome.waiting);
    final unread = reads.where((r) => r.outcome == CaptureOutcome.unread);
    final moved = [
      for (final read in reads)
        if (read.outcome == CaptureOutcome.moved) read,
    ];
    if (saved.isEmpty && waiting.isEmpty && moved.isNotEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(movedNotice(moved).text)));
      return;
    }
    if (saved.isEmpty && waiting.isEmpty) {
      if (unread.isEmpty) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              "Penny couldn't read a payment message. She'll try again when "
              "you're online.",
            ),
          ),
        );
      return;
    }
    if (saved.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              waiting.length == 1
                  ? 'Penny read ${waiting.single.what}'
                  : 'Penny read ${waiting.length} payments',
            ),
          ),
        );
      return;
    }
    final first = saved.first;
    final firstSms = first.sms!;
    showUndoSnackBarOn(
      messenger,
      message: [
        saved.length == 1
            ? 'Added ${formatPaise(firstSms.amountPaise)} · '
                  '${kindLabel(firstSms.type, first.categoryId!)} '
                  'from a notification'
            : 'Added ${saved.length} payments from notifications',
        if (waiting.isNotEmpty) '${waiting.length} more to check on Home',
      ].join('. '),
      onUndo: () async {
        final txns = ref.read(txnRepositoryProvider);
        final captures = ref.read(captureRepositoryProvider);
        for (final one in saved) {
          await txns.softDelete(one.entryId!);
          await captures.hold(
            one.sms!,
            app: one.app,
            at: one.at,
            sender: one.sender,
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _shares.cancel();
    _captures.cancel();
    _openHome.cancel();
    _refreshed.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Penny',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      scaffoldMessengerKey: _messenger,
      routerConfig: ref.watch(routerProvider),
      // Penny's own lock, when it's on, covers everything.
      builder: (context, child) => LockGate(child: child!),
    );
  }
}
