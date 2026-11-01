import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/config.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/month_insight.dart';
import 'package:penny/models/txn_enums.dart';
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

/// One turn of the chat, as Penny is sent it.
typedef ChatTurn = ({ChatRole role, String text});

/// What goes to penny-chat: this month as the report would send it, each
/// group's tag as the phone works it out, and the conversation so far.
@immutable
class ChatRequest {
  const ChatRequest({
    required this.month,
    required this.tags,
    required this.turns,
  });

  final InsightRequest month;
  final Map<String, TxnTag> tags;

  /// Oldest first, ending with the user.
  final List<ChatTurn> turns;

  Map<String, Object?> toJson() => {
    'v': 1,
    'month': month.body,
    'tags': {
      for (final MapEntry(:key, :value) in tags.entries) key: value.name,
    },
    'messages': [
      for (final turn in turns) {'role': turn.role.name, 'text': turn.text},
    ],
  };
}

/// Penny's reply in the chat.
@immutable
class ChatAnswer {
  const ChatAnswer({required this.reply, this.callsLeftToday});

  final String reply;
  final int? callsLeftToday;
}

/// Asks Penny's server for a look at one month, or for a chat reply.
abstract interface class AiClient {
  /// Whether this build knows where Penny's server is.
  bool get isSetUp;

  /// Penny's look at [request]'s month. Throws [AiException] when there is
  /// no answer.
  Future<AiAnswer> analyzeMonth(InsightRequest request);

  /// Penny's reply to the last turn in [request]. Throws [AiException] when
  /// there is none.
  Future<ChatAnswer> chat(ChatRequest request);
}

/// [AiClient] over the analyze-month and penny-chat Edge Functions.
/// Supabase starts, and the phone signs in anonymously (no email, no name),
/// only the first time Penny is asked.
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
  Future<AiAnswer> analyzeMonth(InsightRequest request) =>
      _call('analyze-month', request.body, (data) => answerFrom(data, request));

  @override
  Future<ChatAnswer> chat(ChatRequest request) =>
      _call('penny-chat', request.toJson(), chatAnswerFrom);

  /// Calls [function] with [body] and reads its reply with [read], which
  /// returns null for a reply that makes no sense.
  Future<T> _call<T>(
    String function,
    Map<String, Object?> body,
    T? Function(Object? data) read,
  ) async {
    if (!isSetUp) throw const AiException(AiFailure.notSetUp);
    try {
      final client = await (_client ??= _start());
      if (client.auth.currentSession == null) {
        await client.auth.signInAnonymously();
      }
      Future<T> invoke() async {
        final response = await client.functions
            .invoke(function, body: body)
            // The server gives Gemini 50 seconds, then answers either way.
            .timeout(const Duration(seconds: 70));
        return read(response.data) ??
            (throw const AiException(AiFailure.badAnswer));
      }

      try {
        return await invoke();
      } on FunctionException catch (error) {
        if (error.status != 401) rethrow;
        // An expired or revoked session: sign in again and retry once.
        await _renewSession(client);
        return await invoke();
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

/// The reply in an answer from penny-chat, or null when it isn't one.
ChatAnswer? chatAnswerFrom(Object? data) {
  if (data is! Map) return null;
  final reply = data['reply'];
  if (reply is! String || reply.trim().isEmpty) return null;
  return ChatAnswer(
    reply: reply.trim(),
    callsLeftToday: switch (data['callsLeftToday']) {
      final int left => left,
      _ => null,
    },
  );
}

/// The chat as Penny is sent it: the last [max] turns, the user's
/// back-to-back messages joined, starting with the user and each cut to
/// what the server takes.
List<ChatTurn> chatTurns(Iterable<ChatMessage> history, {int max = 12}) {
  final turns = <ChatTurn>[];
  for (final message in history) {
    final text = message.body.trim();
    if (text.isEmpty) continue;
    if (turns.isNotEmpty && turns.last.role == message.role) {
      turns.last = (role: message.role, text: '${turns.last.text}\n$text');
    } else {
      turns.add((role: message.role, text: text));
    }
  }
  var recent = turns.length > max ? turns.sublist(turns.length - max) : turns;
  while (recent.isNotEmpty && recent.first.role == ChatRole.penny) {
    recent = recent.sublist(1);
  }
  return [
    for (final turn in recent)
      (
        role: turn.role,
        text: turn.text.length > 1000
            ? turn.text.substring(0, 1000)
            : turn.text,
      ),
  ];
}

final aiClientProvider = Provider<AiClient>((ref) => SupabaseAiClient());
