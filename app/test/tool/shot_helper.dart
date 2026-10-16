import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';

const shotsDir = String.fromEnvironment(
  'SHOTS_DIR',
  defaultValue: '/tmp/inkslot_shots',
);

Future<void> loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  await load('Geist', ['assets/fonts/Geist-Variable.woff2']);
  await load('Geist Mono', [
    'assets/fonts/GeistMono-Regular.woff2',
    'assets/fonts/GeistMono-Medium.woff2',
  ]);
  await load('Instrument Serif', [
    'assets/fonts/InstrumentSerif-Regular.woff2',
    'assets/fonts/InstrumentSerif-Italic.woff2',
  ]);
}

/// Renders [home] at 390x844 @2x and writes `$shotsDir/$name.png`.
Future<void> shot(
  WidgetTester tester,
  String name,
  Widget home, {
  Duration settle = const Duration(milliseconds: 1500),
  Future<void> Function(WidgetTester)? after,
}) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildInkSlotTheme(),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(settle);
  if (after != null) await after(tester);
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$shotsDir/$name.png')..createSync(recursive: true);
    f.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
