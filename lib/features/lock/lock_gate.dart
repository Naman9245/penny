import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/core/theme/app_text.dart';
import 'package:penny/services/app_lock.dart';
import 'package:penny/widgets/brutal_button.dart';
import 'package:penny/widgets/penny_mascot.dart';

/// Covers the whole app while Penny is locked, and notes when she goes to
/// the background and comes back. What's under it keeps its place.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(lockedProvider.notifier).away(DateTime.now()),
      onShow: () => ref.read(lockedProvider.notifier).back(DateTime.now()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(lockedProvider);
    return Stack(
      children: [
        // Hidden from screen readers too while locked.
        ExcludeSemantics(excluding: locked, child: widget.child),
        if (locked) const Positioned.fill(child: _LockScreen()),
      ],
    );
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  @override
  void initState() {
    super.initState();
    // Asks straight away, as the lock shows.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(lockedProvider.notifier).unlock();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const ValueKey('lock-screen'),
      color: AppColors.cream,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PennyMascot(size: 120),
              const SizedBox(height: 20),
              const Text(
                'Penny is locked',
                style: AppText.h1,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Use your fingerprint or your phone’s PIN to open her.',
                style: AppText.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              BrutalButton(
                key: const ValueKey('unlock'),
                label: 'Unlock',
                icon: Icons.lock_open_rounded,
                expand: true,
                onPressed: () => ref.read(lockedProvider.notifier).unlock(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
