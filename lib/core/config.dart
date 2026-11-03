/// Where Penny's server lives, set when the app is built:
///
///     flutter run --dart-define-from-file=env/supabase.json
///
/// A build without it works as before, just without Penny's report. The
/// publishable key is public by design; row-level security and the Edge
/// Function guard everything behind it.
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Google's id for the server side of sign-in, which Supabase checks
  /// Google sign-ins against. Public, like the key. Without it there's no
  /// "Back up with Google".
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  static bool get isSet => url.isNotEmpty && publishableKey.isNotEmpty;
}
