import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/config.dart';
import 'package:penny/data/account.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/sync/sync_engine.dart';
import 'package:penny/data/sync/sync_remote.dart';

/// Where the backup stands, for Settings.
enum SyncPhase {
  /// No account: nothing leaves the phone.
  off,

  /// Demo data is on; the user's own money waits for it to end.
  paused,
  syncing,
  synced,

  /// No connection. It tries again when the app comes back, or after the
  /// next change.
  offline,
  failed,
}

@immutable
class SyncStatus {
  const SyncStatus(this.phase, {this.lastSynced});

  final SyncPhase phase;

  /// When the last sync finished, while the app has been open.
  final DateTime? lastSynced;
}

/// The signed-in account's copy; null in a build without Penny's server.
final syncRemoteProvider = Provider<SyncRemote?>(
  (ref) => SupabaseConfig.isSet ? SupabaseSyncRemote() : null,
);

/// How long after a change sync waits, so a burst of edits goes up at once.
final syncSettleProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

final syncControllerProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

/// Keeps the account's copy up to date: right after signing in, when the
/// app opens or comes back, a few seconds after a change, and on request.
/// Never with no account, or while demo data is on.
class SyncController extends Notifier<SyncStatus> {
  Timer? _soon;
  var _running = false;
  var _again = false;
  DateTime? _last;

  @override
  SyncStatus build() {
    final account = ref.watch(accountProvider).value;
    final remote = ref.watch(syncRemoteProvider);
    final demo = ref.watch(demoModeProvider);
    ref.onDispose(() => _soon?.cancel());
    if (account == null || remote == null) {
      return const SyncStatus(SyncPhase.off);
    }
    if (demo) return SyncStatus(SyncPhase.paused, lastSynced: _last);

    final engine = SyncEngine(ref.watch(appDatabaseProvider), remote);
    final waiting = engine.watchWaiting().listen((count) {
      if (count == 0) {
        _soon?.cancel();
      } else if (!_running) {
        _soon?.cancel();
        _soon = Timer(ref.read(syncSettleProvider), syncNow);
      }
    });
    ref.onDispose(waiting.cancel);
    // Just signed in, just opened, or the demo just ended: sync now.
    scheduleMicrotask(syncNow);
    return SyncStatus(SyncPhase.syncing, lastSynced: _last);
  }

  /// Syncs now, or once more after the sync under way.
  Future<void> syncNow() async {
    if (!ref.mounted) return;
    _soon?.cancel();
    final account = ref.read(accountProvider).value;
    final remote = ref.read(syncRemoteProvider);
    if (account == null || remote == null || ref.read(demoModeProvider)) {
      return;
    }
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    state = SyncStatus(SyncPhase.syncing, lastSynced: _last);
    var phase = SyncPhase.synced;
    try {
      do {
        _again = false;
        await SyncEngine(
          ref.read(appDatabaseProvider),
          remote,
        ).sync(account.id);
      } while (_again && ref.mounted);
      _last = DateTime.now();
    } on SyncException catch (error) {
      phase = error.failure == SyncFailure.offline
          ? SyncPhase.offline
          : SyncPhase.failed;
    } on Exception {
      phase = SyncPhase.failed;
    } finally {
      _running = false;
    }
    if (ref.mounted) state = SyncStatus(phase, lastSynced: _last);
  }
}
