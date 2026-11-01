import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/insight_builder.dart';
import 'package:penny/services/penny_ai.dart';

/// Where asking Penny about a month stands.
@immutable
class AskState {
  const AskState({this.asking = false, this.failure, this.callsLeftToday});

  final bool asking;

  /// Why the last ask got no answer.
  final AiException? failure;

  /// From the server's last answer, when there was one.
  final int? callsLeftToday;
}

final askPennyProvider = NotifierProvider.autoDispose
    .family<AskPennyController, AskState, DateTime>(AskPennyController.new);

class AskPennyController extends Notifier<AskState> {
  AskPennyController(this.month);

  final DateTime month;

  @override
  AskState build() => const AskState();

  /// Sends [request] to Penny and keeps her answer as the month's report.
  /// Only ever runs because someone tapped Ask Penny or Refresh.
  Future<void> ask(InsightRequest request) async {
    if (state.asking || !request.canAsk) return;
    // Read up front: the screen may close while Penny thinks, and the answer
    // is still worth keeping.
    final ai = ref.read(aiClientProvider);
    final insights = ref.read(insightRepositoryProvider);
    state = AskState(asking: true, callsLeftToday: state.callsLeftToday);
    try {
      final answer = await ai.analyzeMonth(request);
      await insights.save(
        request: request,
        insight: answer.insight,
        model: answer.model,
      );
      if (ref.mounted) state = AskState(callsLeftToday: answer.callsLeftToday);
    } on AiException catch (failure) {
      if (ref.mounted) {
        state = AskState(
          failure: failure,
          callsLeftToday: state.callsLeftToday,
        );
      }
    }
  }
}
