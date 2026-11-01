import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/core/router/app_router.dart';
import 'package:penny/core/theme/app_theme.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/services/share_inbox.dart';
import 'package:penny/services/sms_parser.dart';

class PennyApp extends ConsumerStatefulWidget {
  const PennyApp({super.key});

  @override
  ConsumerState<PennyApp> createState() => _PennyAppState();
}

class _PennyAppState extends ConsumerState<PennyApp> {
  late final StreamSubscription<String> _shares;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final inbox = ref.read(shareInboxProvider);
    _shares = inbox.shared.listen(_review);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final text = await inbox.takeLaunchShare();
      if (text != null && mounted) _review(text);
    });
    // Sharing from Messages can open a second copy of Penny on top of it.
    // When this copy comes back to the front, re-read what that one saved.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final db = ref.read(appDatabaseProvider);
        db.markTablesUpdated([db.txns]);
      },
    );
  }

  /// Reads a shared SMS on the phone and opens its review.
  void _review(String text) {
    ref.read(routerProvider).push('/import', extra: parseSms(text));
  }

  @override
  void dispose() {
    _shares.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Penny',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
