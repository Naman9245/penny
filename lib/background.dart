import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/widgets.dart';
import 'package:penny/data/capture_repository.dart';
import 'package:penny/data/db/app_database.dart';
import 'package:penny/data/prefs_repository.dart';
import 'package:penny/data/providers.dart';
import 'package:penny/data/txn_repository.dart';
import 'package:penny/services/captures.dart';
import 'package:penny/services/notification_inbox.dart';
import 'package:penny/services/penny_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Penny's hidden copy, which Android starts when payment notifications
/// arrive while she's closed (see BackgroundReader.kt): it reads them with
/// the same rules as the open app, posts her notification, and says it's
/// done so Android closes it.
Future<void> readInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final inbox = NotificationInbox();
  try {
    await readWaiting(
      inbox: inbox,
      prefs: await SharedPreferences.getInstance(),
      open: AppDatabase.named,
      ai: SupabaseAiClient(),
    );
  } finally {
    await inbox.done();
  }
}

/// What [readInBackground] does once started: takes everything waiting in
/// [inbox] into the user's own database, opened with [open], asking [ai]
/// about what the rules can't read, goes round again while more arrive, and
/// posts one notification about it all. With demo data on, they wait for
/// the user's own money.
Future<List<CaptureRead>> readWaiting({
  required NotificationInbox inbox,
  required SharedPreferences prefs,
  required AppDatabase Function(String name) open,
  AiClient? ai,
}) async {
  if (prefs.getBool(DemoMode.key) ?? false) return const [];
  final db = open('penny');
  final reads = <CaptureRead>[];
  try {
    final mode = CaptureModeSetting.of(prefs);
    do {
      final round = await takeCaptures(
        source: inbox,
        db: db,
        txns: TxnRepository(db),
        captures: CaptureRepository(db),
        mode: mode,
        now: DateTime.now(),
        ai: ai,
      );
      await noteReads(PrefsRepository(db), round);
      reads.addAll(round);
    } while (await inbox.again());
  } finally {
    await db.close();
  }
  if (noticeFor(reads) case final notice?) await inbox.notify(notice);
  return reads;
}
