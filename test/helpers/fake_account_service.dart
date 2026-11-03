import 'dart:async';

import 'package:penny/data/account.dart';

/// Signing in without Google: it gives [next] at once.
class FakeAccountService implements AccountService {
  FakeAccountService({
    this.canSignIn = true,
    this.next = const Account(id: 'account-1', email: 'me@example.com'),
    Account? signedIn,
  }) : _current = signedIn;

  @override
  final bool canSignIn;

  /// Who signing in signs in as.
  final Account? next;
  Account? _current;
  final _changes = StreamController<Account?>.broadcast();

  /// While true, signing in and deleting fail as if offline.
  bool offline = false;

  /// How many times the account was deleted.
  var deleted = 0;

  @override
  Stream<Account?> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<Account?> signInWithGoogle() async {
    _check();
    _set(next);
    return next;
  }

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<void> deleteAccount() async {
    _check();
    deleted++;
    _set(null);
  }

  void _check() {
    if (offline) throw const AccountException(AccountFailure.offline);
  }

  void _set(Account? account) {
    _current = account;
    _changes.add(account);
  }
}
