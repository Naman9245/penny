import 'package:penny/core/config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<SupabaseClient>? _started;

/// Penny's server, started once, the first time anything needs it: the AI,
/// signing in, or sync. It brings back a saved sign-in. A start that fails,
/// say offline on first launch, is tried again next time.
Future<SupabaseClient> startSupabase() => _started ??= _start();

Future<SupabaseClient> _start() async {
  try {
    final supabase = await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    return supabase.client;
  } catch (_) {
    _started = null;
    rethrow;
  }
}
