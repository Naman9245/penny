import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:penny/data/providers.dart';

/// Checks it's the phone's owner: their fingerprint or face, or the phone's
/// own PIN, pattern or password.
abstract interface class Authenticator {
  /// Whether the phone has a screen lock to check against.
  Future<bool> canCheck();

  /// Whether the owner showed it's them. [reason] is shown while asking.
  Future<bool> check(String reason);
}

/// [Authenticator] through Android's own fingerprint and screen lock.
class DeviceAuthenticator implements Authenticator {
  final _auth = LocalAuthentication();

  @override
  Future<bool> canCheck() async {
    try {
      return await _auth.isDeviceSupported();
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> check(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}

final authenticatorProvider = Provider<Authenticator>(
  (ref) => DeviceAuthenticator(),
);

/// What turning the lock on or off came to.
enum LockChange {
  done,

  /// The phone has no screen lock, so there's nothing to check against.
  noScreenLock,

  /// The check wasn't passed.
  notYou,
}

/// Whether Penny asks for the owner when she opens. Off until turned on.
final appLockProvider = NotifierProvider<AppLock, bool>(AppLock.new);

class AppLock extends Notifier<bool> {
  /// Where it's kept.
  static const key = 'app_lock';

  @override
  bool build() => ref.watch(sharedPrefsProvider).getBool(key) ?? false;

  /// Turns the lock on or off. Either way the owner shows it's them first,
  /// so no one else can turn it off.
  Future<LockChange> set(bool on) async {
    if (on == state) return LockChange.done;
    final auth = ref.read(authenticatorProvider);
    if (!await auth.canCheck()) return LockChange.noScreenLock;
    if (!await auth.check(on ? 'Turn on the lock' : 'Turn off the lock')) {
      return LockChange.notYou;
    }
    await ref.read(sharedPrefsProvider).setBool(key, on);
    state = on;
    return LockChange.done;
  }
}

/// How long Penny can be away before she locks again.
const lockAfter = Duration(minutes: 1);

/// Whether Penny is locked now: as she opens with the lock on, and when she
/// comes back after [lockAfter] away.
final lockedProvider = NotifierProvider<Locked, bool>(Locked.new);

class Locked extends Notifier<bool> {
  DateTime? _away;

  // Read, not watched: turning the lock on doesn't lock her there and then.
  @override
  bool build() => ref.read(appLockProvider);

  /// Penny went to the background at [at].
  void away(DateTime at) => _away = at;

  /// Penny came back at [at]: locked when she was away long enough.
  void back(DateTime at) {
    final away = _away;
    _away = null;
    if (away != null &&
        ref.read(appLockProvider) &&
        at.difference(away) >= lockAfter) {
      state = true;
    }
  }

  /// Asks for the owner, and unlocks when it's them.
  Future<void> unlock() async {
    if (await ref.read(authenticatorProvider).check('Unlock Penny')) {
      state = false;
    }
  }
}
