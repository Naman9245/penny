import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_pill.dart';

/// Settings' "Read payment notifications": whether Penny may, the way to
/// allow it on Android's own page, and what happens to a payment she reads.
class NotificationsCard extends ConsumerStatefulWidget {
  const NotificationsCard({super.key});

  @override
  ConsumerState<NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends ConsumerState<NotificationsCard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android's page: ask again whether it's allowed now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationAccessProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = ref.watch(notificationAccessProvider).value ?? false;
    final mode = ref.watch(captureModeProvider);
    final setMode = ref.read(captureModeProvider.notifier).set;
    return BrutalCard(
      key: const ValueKey('notifications-card'),
      color: allowed ? AppColors.mint : AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Read payment notifications', style: AppText.h3),
              ),
              BrutalPill(
                key: const ValueKey('notifications-status'),
                label: allowed ? 'On' : 'Off',
                color: allowed ? AppColors.white : AppColors.cream,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            allowed
                ? 'Penny reads payments from your SMS app, GPay, PhonePe and '
                      "Paytm, so you don't have to type them."
                : 'Let Penny read payments from your SMS app, GPay, PhonePe '
                      "and Paytm, so you don't have to type them.",
            style: AppText.body,
          ),
          const SizedBox(height: 10),
          BrutalButton(
            key: const ValueKey('notifications-settings'),
            label: allowed ? 'Notification access' : 'Turn on',
            icon: allowed
                ? Icons.settings_outlined
                : Icons.notifications_active_outlined,
            color: allowed ? AppColors.white : AppColors.yellow,
            expand: true,
            onPressed: ref.read(notificationInboxProvider).openSettings,
          ),
          const SizedBox(height: 4),
          Text(
            allowed
                ? "You can turn it off on Android's Notification access page."
                : "Android asks you to allow Penny on its Notification access "
                      'page.',
            style: AppText.small,
          ),
          const SizedBox(height: 14),
          const Text('When Penny reads a payment', style: AppText.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              BrutalChip(
                key: const ValueKey('capture-check'),
                label: 'Wait for me to check',
                selected: mode == CaptureMode.check,
                onTap: () => setMode(CaptureMode.check),
              ),
              BrutalChip(
                key: const ValueKey('capture-save'),
                label: 'Save straight away',
                selected: mode == CaptureMode.save,
                onTap: () => setMode(CaptureMode.save),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mode == CaptureMode.check
                ? 'They wait on Home for you to add or skip.'
                : "They're saved as soon as Penny reads them. Any that may "
                      'already be logged, or need a category, still wait for '
                      'you on Home.',
            style: AppText.small.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          const Text(
            'Only those apps, and only what looks like a payment. It stays on '
            "this phone, and people's names never reach the AI.",
            style: AppText.small,
          ),
        ],
      ),
    );
  }
}
