import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/services/app_lock.dart';
import 'package:penny/widgets/brutal_card.dart';
import 'package:penny/widgets/brutal_chip.dart';
import 'package:penny/widgets/brutal_pill.dart';

/// Settings → Lock Penny: her own lock, on the phone's fingerprint or
/// screen lock.
class LockCard extends ConsumerStatefulWidget {
  const LockCard({super.key});

  @override
  ConsumerState<LockCard> createState() => _LockCardState();
}

class _LockCardState extends ConsumerState<LockCard> {
  /// Why the last switch didn't happen, if it didn't.
  String? _problem;
  var _busy = false;

  Future<void> _set(bool on) async {
    setState(() => _busy = true);
    final change = await ref.read(appLockProvider.notifier).set(on);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _problem = switch (change) {
        LockChange.done => null,
        LockChange.noScreenLock =>
          'Set a screen lock on your phone first, in Android’s Security '
              'settings.',
        LockChange.notYou => 'That didn’t check out, so nothing changed.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(appLockProvider);
    return BrutalCard(
      key: const ValueKey('lock-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Lock Penny', style: AppText.label)),
              if (on)
                const BrutalPill(
                  key: ValueKey('app-lock-on'),
                  label: 'On',
                  color: AppColors.white,
                ),
              const SizedBox(width: 8),
              BrutalChip(
                key: const ValueKey('app-lock'),
                label: on ? 'Turn off' : 'Turn on',
                icon: on ? Icons.lock_open_rounded : Icons.lock_rounded,
                onTap: _busy ? null : () => _set(!on),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Asks for your fingerprint or your phone’s PIN when Penny opens, '
            'and when you come back after a minute away. Her notifications '
            'still come.',
            style: AppText.small,
          ),
          if (_problem case final problem?) ...[
            const SizedBox(height: 6),
            Text(
              problem,
              key: const ValueKey('app-lock-problem'),
              style: AppText.small.copyWith(color: AppColors.ink),
            ),
          ],
        ],
      ),
    );
  }
}
