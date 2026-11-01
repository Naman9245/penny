import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/config.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Why Penny couldn't answer.
enum AiFailure {
  /// This build doesn't know where Penny's server is.
  notSetUp,

  /// The server is missing its Gemini key.
  serverNotReady,
  signInOff,
  offline,
  dailyLimit,
  busy,

  /// Gemini didn't answer in time.
  slow,
  unavailable,
  badAnswer,
}

/// Penny had no answer. [message] says why, in words the report can show.
class AiException implements Exception {
  const AiException(this.failure, {this.limit});

  final AiFailure failure;

  /// Looks per day, for [AiFailure.dailyLimit].
  final int? limit;

  String get message => switch (failure) {
    AiFailure.notSetUp => "Penny's AI isn't set up in this build yet.",
    AiFailure.serverNotReady =>
      "Penny's server isn't ready yet: its Gemini key is missing.",
    AiFailure.signInOff =>
      "Penny can't sign in yet: anonymous sign-ins are off in Supabase.",
    AiFailure.offline => "You're offline. Connect and try again.",
    AiFailure.dailyLimit =>
      'Penny can look ${limit ?? 'only a few'} times a day. '
          'Try again tomorrow.',
    AiFailure.busy => 'Penny is busy right now. Try again in a little while.',
    AiFailure.slow => 'Penny took too long to answer. Try again in a minute.',
    AiFailure.unavailable => "Penny couldn't think just now. Try again soon.",
    AiFailure.badAnswer => 'Penny got muddled. Try again.',
  };

  @override
  String toString() => 'AiException($failure)';
}

/// What came back from a look at a month.
@immutable
class AiAnswer {
  const AiAnswer({
    required this.insight,
    required this.model,
    this.callsLeftToday,
  });

  final MonthInsight insight;
  final String model;
  final int? callsLeftToday;
}

/// Asks Penny's server for a look at one month.
abstract interface class AiClient {
  /// Whether this build knows where Penny's server is.
  bool get isSetUp;

  /// Penny's look at [request]'s month. Throws [AiException] when there is
  /// no answer.
  Future<AiAnswer> analyzeMonth(InsightRequest request);
}

/// [AiClient] over the analyze-month Edge Function. Supabase starts, and
/// the phone signs in anonymously (no email, no name), only the first time
/// Penny is asked.
class SupabaseAiClient implements AiClient {
  SupabaseAiClient({
    this._url = SupabaseConfig.url,
    this._publishableKey = SupabaseConfig.publishableKey,
  });

  final String _url;
  final String _publishableKey;
  Future<SupabaseClient>? _client;

  @override
  bool get isSetUp => _url.isNotEmpty && _publishableKey.isNotEmpty;

  @override
  Future<AiAnswer> analyzeMonth(InsightRequest request) async {
    if (!isSetUp) throw const AiException(AiFailure.notSetUp);
    try {
      final client = await (_client ??= _start());
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      try {
        return await _invoke(client, request);
      } on FunctionException catch (error) {
        if (error.status != 401) rethrow;
        // An expired or revoked session: sign in again and retry once.
        await _renewSession(client);
        return await _invoke(client, request);
      }
    } on AiException {
      rethrow;
    } on FunctionException catch (error) {
      throw aiExceptionFor(error.status, error.details);
    } on AuthException catch (error) {
      throw switch (error) {
        AuthRetryableFetchException() => const AiException(AiFailure.offline),
        _ when error.code == 'anonymous_provider_disabled' => const AiException(
          AiFailure.signInOff,
        ),
        _ => const AiException(AiFailure.unavailable),
      };
    } on TimeoutException {
      throw const AiException(AiFailure.slow);
    } on Exception {
      throw const AiException(AiFailure.unavailable);
    }
  }

  Future<SupabaseClient> _start() async {
    try {
      final supabase = await Supabase.initialize(
        url: _url,
        publishableKey: _publishableKey,
      );
      return supabase.client;
    } catch (_) {
      _client = null;
      rethrow;
    }
  }

  Future<AiAnswer> _invoke(
    SupabaseClient client,
    InsightRequest request,
  ) async {
    final response = await client.functions
        .invoke('analyze-month', body: request.body)
        // The server gives Gemini 50 seconds, then answers either way.
        .timeout(const Duration(seconds: 70));
    return answerFrom(response.data, request) ??
        (throw const AiException(AiFailure.badAnswer));
  }

  Future<void> _renewSession(SupabaseClient client) async {
    try {
      await client.auth.refreshSession();
    } on AuthException {
      await client.auth.signInAnonymously();
    }
  }
}

/// The failure an error reply from analyze-month stands for. Status 0 means
/// the request never reached the server.
AiException aiExceptionFor(int status, Object? details) {
  if (status == 0) return const AiException(AiFailure.offline);
  final reply = details is Map ? details : const {};
  return switch (reply['error']) {
    'daily_limit' => AiException(
      AiFailure.dailyLimit,
      limit: switch (reply['limit']) {
        final int limit => limit,
        _ => null,
      },
    ),
    'busy' => const AiException(AiFailure.busy),
    'too_slow' => const AiException(AiFailure.slow),
    'not_configured' => const AiException(AiFailure.serverNotReady),
    'bad_answer' => const AiException(AiFailure.badAnswer),
    _ => const AiException(AiFailure.unavailable),
  };
}

/// The answer in a reply from analyze-month, or null when it isn't one.
/// Ids that [request] didn't send are dropped.
AiAnswer? answerFrom(Object? data, InsightRequest request) {
  if (data is! Map) return null;
  final insight = MonthInsight.fromJson(
    data['insight'],
    groupIds: request.groupKeys.keys.toSet(),
  );
  final model = data['model'];
  if (insight == null || model is! String) return null;
  return AiAnswer(
    insight: insight,
    model: model,
    callsLeftToday: switch (data['callsLeftToday']) {
      final int left => left,
      _ => null,
    },
  );
}

final aiClientProvider = Provider<AiClient>((ref) => SupabaseAiClient());
