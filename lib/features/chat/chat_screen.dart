import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/core/theme/brutal_theme.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/features/chat/chat_controller.dart';
import 'package:penny/features/report/sent_sheet.dart';
import 'package:penny/models/chat.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/models/penny_pose.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_icon_button.dart';
import 'package:penny/widgets/penny_mascot.dart';
import 'package:penny/widgets/page_header.dart';

/// Talk to Penny: ask her anything about your money, in English, Hindi or
/// Hinglish. She sees this month's totals, your My needs rules and note,
/// and the chat so far. The chat itself stays on this phone.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _ideas = [
    'Where am I wasting money?',
    'How can I spend less on food?',
    'Ideas to earn extra as a student',
  ];

  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send(String text) {
    final message = text.trim();
    if (message.isEmpty || ref.read(chatControllerProvider).sending) return;
    _text.clear();
    ref.read(chatControllerProvider.notifier).send(message);
  }

  Future<void> _clear() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the chat?'),
        content: const Text("It's only on this phone, so it's gone for good."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const ValueKey('confirm-clear-chat'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (sure ?? false) await ref.read(chatControllerProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final messages =
        ref.watch(chatMessagesProvider).value ?? const <ChatMessage>[];
    // What goes along with each message.
    final sent = ref.watch(chatMonthProvider).value;
    final chat = ref.watch(chatControllerProvider);
    final setUp = ref.watch(aiClientProvider).isSetUp;
    final failure = chat.sending ? null : chat.failure;

    // The list is reversed, so it starts at the bottom with the newest.
    final items = <Widget>[
      if (failure != null)
        _Problem(
          failure: failure,
          onRetry: ref.read(chatControllerProvider.notifier).retry,
        ),
      if (chat.sending) const _Typing(),
      for (final message in messages.reversed) _Bubble(message: message),
      if (messages.isEmpty)
        _Welcome(ideas: _ideas, onIdea: setUp ? _send : null),
      _AboutChat(
        onSeeSent: sent == null
            ? null
            : () => showSentSheet(context, sent.month, goals: sent.goals),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: PageHeader(
                title: 'Talk to Penny',
                subtitle: 'Your money buddy',
                actions: [
                  // Not while she's answering: her reply would land in an
                  // empty chat.
                  if (messages.isNotEmpty && !chat.sending)
                    BrutalIconButton(
                      key: const ValueKey('clear-chat'),
                      icon: Icons.delete_outline_rounded,
                      semanticLabel: 'Clear chat',
                      onPressed: _clear,
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: item,
                    ),
                ],
              ),
            ),
            _Composer(
              controller: _text,
              setUp: setUp,
              left: chat.callsLeftToday,
              onSend: chat.sending ? null : () => _send(_text.text),
            ),
          ],
        ),
      ),
    );
  }
}

/// What Penny sees and where the chat goes, at the top of the chat.
class _AboutChat extends StatelessWidget {
  const _AboutChat({required this.onSeeSent});

  final VoidCallback? onSeeSent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Penny sees this month's totals and your messages, never your SMS. "
          'Chats go to Google Gemini, which may use them to improve its AI, '
          'so never share passwords, OTPs or account numbers. Chat numbers '
          "can be rough; the report's are exact.",
          style: AppText.small,
          textAlign: TextAlign.center,
        ),
        if (onSeeSent case final onTap?) ...[
          const SizedBox(height: 8),
          BrutalChip(
            key: const ValueKey('chat-see-sent'),
            label: 'See what Penny sends',
            icon: Icons.visibility_outlined,
            onTap: onTap,
          ),
        ],
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.ideas, required this.onIdea});

  final List<String> ideas;

  /// Null when Penny can't be asked from this build.
  final ValueChanged<String>? onIdea;

  @override
  Widget build(BuildContext context) {
    final onIdea = this.onIdea;
    return Column(
      children: [
        const PennyMascot(mood: PennyMood.happy),
        const SizedBox(height: 10),
        const Text(
          "Hi! I'm Penny. Ask me anything about your money.",
          style: AppText.h3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'English, Hindi or Hinglish, all fine.',
          style: AppText.bodyMuted,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final idea in ideas)
              BrutalChip(
                label: idea,
                onTap: onIdea == null ? null : () => onIdea(idea),
              ),
          ],
        ),
      ],
    );
  }
}

/// One message: the user's in yellow on the right, Penny's on the left
/// with her face.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == ChatRole.user;
    final bubble = _BubbleBox(
      color: mine ? AppColors.yellow : AppColors.white,
      child: Text(message.body, style: AppText.body),
    );
    if (mine) return Align(alignment: Alignment.centerRight, child: bubble);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const PennyMascot(size: 34, bob: false),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }
}

class _BubbleBox extends StatelessWidget {
  const _BubbleBox({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: brutalDecoration(
          color: color,
          radius: 20,
          borderWidth: 2,
          shadow: const Offset(2, 2),
        ),
        child: child,
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: ValueKey('penny-typing'),
      children: [
        PennyMascot(pose: PennyPose.thinking, size: 34),
        SizedBox(width: 8),
        Text('Penny is typing…', style: AppText.bodyMuted),
      ],
    );
  }
}

/// Why Penny didn't reply, in a bubble of her own.
class _Problem extends StatelessWidget {
  const _Problem({required this.failure, required this.onRetry});

  final AiException failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = switch (failure) {
      // The report's wording counts looks; the chat counts messages.
      AiException(failure: AiFailure.dailyLimit, :final limit) =>
        'Penny can answer ${limit ?? 'only a few'} messages a day. '
            'Try again tomorrow.',
      _ => failure.message,
    };
    return Row(
      key: const ValueKey('chat-problem'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const PennyMascot(mood: PennyMood.worried, size: 34, bob: false),
        const SizedBox(width: 8),
        Flexible(
          child: _BubbleBox(
            color: AppColors.pink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: AppText.bodyStrong),
                const SizedBox(height: 8),
                BrutalChip(
                  label: 'Try again',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.setUp,
    required this.left,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool setUp;

  /// Messages left today, from Penny's last reply.
  final int? left;

  /// Null while Penny is answering.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(kPillRadius)),
      borderSide: BorderSide(color: AppColors.ink, width: 2.5),
    );
    final left = this.left;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.hairline, width: 1.5)),
      ),
      child: !setUp
          ? const Text(
              "Penny's AI isn't set up in this build yet.",
              style: AppText.bodyStrong,
              textAlign: TextAlign.center,
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (left != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      left == 1
                          ? '1 more message today'
                          : '$left more messages today',
                      style: AppText.small,
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('chat-input'),
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        // What the server takes in one message.
                        maxLength: 1000,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppText.body,
                        decoration: const InputDecoration(
                          hintText: 'Ask Penny…',
                          counterText: '',
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          border: border,
                          enabledBorder: border,
                          focusedBorder: border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BrutalIconButton(
                      key: const ValueKey('chat-send'),
                      icon: Icons.arrow_upward_rounded,
                      semanticLabel: 'Send',
                      color: AppColors.yellow,
                      onPressed: onSend,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
