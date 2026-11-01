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
}
