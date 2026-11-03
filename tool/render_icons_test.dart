import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penny/core/theme/app_colors.dart';
import 'package:penny/models/penny_mood.dart';
import 'package:penny/widgets/penny_mascot.dart';

// Draws the app icon and the launch screen's Penny from her own drawing, so
// they always match her. Run after changing how she looks:
//
//   flutter test tool/render_icons_test.dart
//   dart run flutter_launcher_icons
//   dart run flutter_native_splash:create

/// Where the images go, beside the configs in pubspec.yaml that use them.
const _out = 'assets/icon';

void main() {
  testWidgets('render the icon and launch images', (tester) async {
    // Penny's ₹ is in Baloo 2; tests draw with a stand-in font otherwise.
    final baloo = FontLoader('Baloo2')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Baloo2-ExtraBold.ttf').readAsBytesSync(),
          ),
        ),
      );
    await baloo.load();

    // The icon: Penny on her yellow, filling most of the square.
    await _render(tester, 'icon.png', 1024, AppColors.yellow, 0.8);
    // The adaptive icon's front layer: launchers crop to a circle 2/3 of
    // the square wide, so she sits inside it, on nothing.
    await _render(tester, 'icon_foreground.png', 1024, null, 0.6);
    // The launch screen: Penny alone; Android 12's needs the same room as
    // the adaptive icon.
    await _render(tester, 'splash.png', 512, null, 1);
    await _render(tester, 'splash_android12.png', 960, null, 0.6);
  });
}

/// Writes Penny, [share] of a [size] square, on [background] or nothing.
Future<void> _render(
  WidgetTester tester,
  String name,
  int size,
  Color? background,
  double share,
) async {
  tester.view.physicalSize = Size.square(size.toDouble());
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ColoredBox(
        color: background ?? const Color(0x00000000),
        child: Center(
          child: MediaQuery(
            // Still: an icon has no time to move in.
            data: const MediaQueryData(disableAnimations: true),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: PennyMascot(mood: PennyMood.happy, size: size * share),
            ),
          ),
        ),
      ),
    ),
  );
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
