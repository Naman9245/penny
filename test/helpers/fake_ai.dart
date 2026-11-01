import 'dart:async';

import 'package:penny/models/month_insight.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';

/// Penny's server, faked: answers with whatever [answer] or [reply] makes of
/// the request, or fails with [failure]. Records every request it gets.
class FakeAiClient implements AiClient {
  FakeAiClient({this.answer, this.reply, this.failure, this.isSetUp = true});

  MonthInsight Function(InsightRequest request)? answer;
  String Function(ChatRequest request)? reply;
  AiException? failure;

  /// While set, chat replies wait for it, so a test can see Penny typing.
  Completer<void>? hold;

  @override
  final bool isSetUp;

  final requests = <InsightRequest>[];
  final chats = <ChatRequest>[];

  @override
  Future<AiAnswer> analyzeMonth(InsightRequest request) async {
    requests.add(request);
    if (failure case final failure?) throw failure;
    final answer = this.answer;
    if (answer == null) throw const AiException(AiFailure.unavailable);
    return AiAnswer(
      insight: answer(request),
      model: 'gemini-3.8-flash',
      callsLeftToday: 9,
    );
  }

  @override
  Future<ChatAnswer> chat(ChatRequest request) async {
    chats.add(request);
    await hold?.future;
    if (failure case final failure?) throw failure;
    final reply = this.reply;
    if (reply == null) throw const AiException(AiFailure.unavailable);
    return ChatAnswer(reply: reply(request), callsLeftToday: 29);
  }
}

/// The id [request] gave the group of spends at [shop], or with no shop
/// name in [categoryId].
String groupId(InsightRequest request, {String? shop, String? categoryId}) {
  final key = shop != null
      ? 'shop|${categoryId ?? 'food'}|${shop.toLowerCase()}'
      : 'cat|$categoryId';
  return request.groupKeys.entries.firstWhere((e) => e.value.contains(key)).key;
}
