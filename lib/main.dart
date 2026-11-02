import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/app.dart';
import 'package:penny/data/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Dark status-bar icons on the cream background.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  LicenseRegistry.addLicense(_fontLicenses);
  // Demo mode opens a second database file beside the user's own. Each has
  // its own connection, so drift's warning about two at once doesn't apply.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Read before the first frame, so the app opens straight onto the right
  // database: the user's own, or the demo.
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const PennyApp(),
    ),
  );
}

/// The bundled fonts are under the SIL Open Font License.
Stream<LicenseEntry> _fontLicenses() async* {
  for (final (family, file) in [('Baloo 2', 'Baloo2'), ('DM Sans', 'DMSans')]) {
    final text = await rootBundle.loadString('assets/fonts/OFL-$file.txt');
    yield LicenseEntryWithLineBreaks([family], text);
  }
}
