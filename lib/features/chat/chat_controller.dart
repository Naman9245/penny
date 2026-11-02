import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/utils/dates.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/txn_enums.dart';
import 'package:penny/services/goal_math.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/insight_math.dart';
import 'package:penny/services/penny_ai.dart';

/// What the chat tells Penny about this month: the month as the report
/// would send it, each group's tag, and the goals. The chat screen keeps it
/// up to date.
final chatMonthProvider =
    FutureProvider.autoDispose<
      ({InsightRequest month, Map<String, TxnTag> tags, List<ChatGoal> goals})
    >((ref) async {
      final now = DateTime.now();
      final month = monthStart(now);
      final request = await ref.watch(insightRequestProvider(month).future);
      final txns = await ref.watch(monthTxnsProvider(month).future);
      final saved = await ref.watch(insightProvider(month).future);
      final rules = await ref.watch(yourRulesProvider.future);
      final goals = await ref.watch(goalsProvider.future);
      final deposits = await ref.watch(goalDepositsProvider.future);
      return (
        month: request,
        tags: groupTags(request, txns, saved, rules: rules),
        // The server takes ten at most; the soonest come first.
        goals: [
          for (final goal in goalProgress(goals, deposits).take(10))
            chatGoalOf(goal, now),
        ],
      );
    });

/// Where the chat with Penny stands.
@immutable
class ChatState {
  const ChatState({this.sending = false, this.failure, this.callsLeftToday});

  /// Waiting for Penny's reply.
  final bool sending;

  /// Why the last message got no reply.
  final AiException? failure;

  /// From Penny's last reply, when there was one.
  final int? callsLeftToday;
}

final chatControllerProvider =
    NotifierProvider.autoDispose<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() {
    // Keeps the month ready for the next message, without starting over
    // each time an entry changes.
    ref.listen(chatMonthProvider, (_, _) {});
    return const ChatState();
  }

  /// Keeps [text] as the user's message and asks Penny about it.
  Future<void> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || state.sending) return;
    await ref.read(chatRepositoryProvider).add(ChatRole.user, message);
    if (ref.mounted) await _ask();
  }

  /// Asks again after a failure. The user's message is already kept.
  Future<void> retry() => _ask();

  /// Empties the chat, and with it any message Penny couldn't answer.
  Future<void> clear() async {
    if (state.sending) return;
    await ref.read(chatRepositoryProvider).clear();
    if (ref.mounted) state = ChatState(callsLeftToday: state.callsLeftToday);
  }

  Future<void> _ask() async {
    if (state.sending) return;
    // Read up front: the screen may close while Penny thinks, and her reply
    // is still worth keeping.
    final ai = ref.read(aiClientProvider);
    final chat = ref.read(chatRepositoryProvider);
    final context = ref.read(chatMonthProvider.future);
    state = ChatState(sending: true, callsLeftToday: state.callsLeftToday);
    try {
      final (:month, :tags, :goals) = await context;
      final answer = await ai.chat(
        ChatRequest(
          month: month,
          tags: tags,
          goals: goals,
          turns: chatTurns(await chat.recent(24)),
        ),
      );
      await chat.add(ChatRole.penny, answer.reply);
      if (ref.mounted) state = ChatState(callsLeftToday: answer.callsLeftToday);
    } on AiException catch (failure) {
      if (ref.mounted) {
        state = ChatState(
          failure: failure,
          callsLeftToday: state.callsLeftToday,
        );
      }
    }
  }
}
