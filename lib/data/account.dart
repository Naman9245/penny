import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:penny/core/config.dart';
import 'package:penny/data/supabase_start.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Google account this phone backs up to.
@immutable
class Account {
  const Account({required this.id, this.email});

  /// Its id on Penny's server: whose copy it is.
  final String id;
  final String? email;

  @override
  bool operator ==(Object other) =>
      other is Account && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

/// Why signing in, or deleting the account, didn't work.
enum AccountFailure { offline, failed }

class AccountException implements Exception {
  const AccountException(this.failure, [this.detail]);

  final AccountFailure failure;
  final String? detail;

  @override
  String toString() => 'AccountException(${failure.name}, $detail)';
}

/// Signing in with Google for backup, and out again. The anonymous sign-in
/// the AI uses never counts as an account.
abstract interface class AccountService {
  /// Whether this build can sign in at all.
  bool get canSignIn;

  /// The signed-in account, as it changes; null when there isn't one.
  Stream<Account?> watch();

  /// Signs in through Google's account picker. Null when the user backs
  /// out of it.
  Future<Account?> signInWithGoogle();

  /// Signs out. The entries stay on the phone.
  Future<void> signOut();

  /// Deletes the account and its copy, then signs out.
  Future<void> deleteAccount();
}

/// [AccountService] over Supabase Auth, with Google's own sign-in on the
/// phone: Google's ID token signs in to Supabase.
class SupabaseAccountService implements AccountService {
  SupabaseAccountService({this.webClientId = SupabaseConfig.googleWebClientId});

  /// Google's id for Supabase's side of sign-in.
  final String webClientId;

  /// Google's sign-in, set up once, the first time it's needed.
  Future<void>? _google;

  @override
  bool get canSignIn => webClientId.isNotEmpty;

  @override
  Stream<Account?> watch() async* {
    final client = await startSupabase();
    yield _accountOf(client.auth.currentUser);
    yield* client.auth.onAuthStateChange.map(
      (change) => _accountOf(change.session?.user),
    );
  }

  static Account? _accountOf(User? user) => user == null || user.isAnonymous
      ? null
      : Account(id: user.id, email: user.email);

  @override
  Future<Account?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    await (_google ??= google.initialize(serverClientId: webClientId));
    final GoogleSignInAccount picked;
    try {
      picked = await google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw AccountException(
        AccountFailure.failed,
        error.description ?? error.code.name,
      );
    }
    final idToken = picked.authentication.idToken;
    if (idToken == null) {
      throw const AccountException(AccountFailure.failed, 'no ID token');
    }
    final client = await startSupabase();
    try {
      final signedIn = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
      return _accountOf(signedIn.user);
    } on AuthRetryableFetchException {
      throw const AccountException(AccountFailure.offline);
    } on AuthException catch (error) {
      throw AccountException(AccountFailure.failed, error.message);
    }
  }

  @override
  Future<void> signOut() async {
    final client = await startSupabase();
    try {
      await client.auth.signOut();
    } on AuthException {
      // Offline: the phone is signed out already; the server lets the
      // session lapse on its own.
    }
    if (_google != null) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Exception {
        // Google's own memory of the choice; nothing here depends on it.
      }
    }
  }

  @override
  Future<void> deleteAccount() async {
    final client = await startSupabase();
    try {
      await client.functions.invoke('delete-account');
    } on FunctionException catch (error) {
      throw AccountException(
        error.status == 0 ? AccountFailure.offline : AccountFailure.failed,
        '${error.status}',
      );
    } on Exception catch (error) {
      throw AccountException(AccountFailure.offline, '$error');
    }
    await signOut();
  }
}

/// Signing in for backup; null in a build without Penny's server.
final accountServiceProvider = Provider<AccountService?>(
  (ref) => SupabaseConfig.isSet ? SupabaseAccountService() : null,
);

/// The account this phone backs up to, if any.
final accountProvider = StreamProvider<Account?>((ref) {
  final service = ref.watch(accountServiceProvider);
  return service == null ? Stream.value(null) : service.watch().distinct();
});
