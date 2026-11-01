import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penny/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Dark status-bar icons on the cream background.
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  LicenseRegistry.addLicense(_fontLicenses);
  runApp(const ProviderScope(child: PennyApp()));
}

/// The bundled fonts are under the SIL Open Font License.
Stream<LicenseEntry> _fontLicenses() async* {
  for (final (family, file) in [('Baloo 2', 'Baloo2'), ('DM Sans', 'DMSans')]) {
    final text = await rootBundle.loadString('assets/fonts/OFL-$file.txt');
    yield LicenseEntryWithLineBreaks([family], text);
  }
}
