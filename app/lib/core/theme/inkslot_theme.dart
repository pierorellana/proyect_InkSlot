import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'inkslot_tokens.dart';

ThemeData buildInkSlotTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'Geist',
  scaffoldBackgroundColor: InkSlotColors.deep,
  colorScheme: const ColorScheme.dark(
    primary: InkSlotColors.copper,
    onPrimary: InkSlotColors.ink,
    surface: InkSlotColors.surface,
    onSurface: InkSlotColors.bone,
    secondary: InkSlotColors.copperLight,
    onSecondary: InkSlotColors.ink,
    error: InkSlotColors.error,
    onError: InkSlotColors.ink,
  ),
  textTheme: const TextTheme(
    displayLarge: TextStyle(
      color: InkSlotColors.bone,
      fontFamily: 'Instrument Serif',
      fontSize: 52,
      height: 0.96,
      fontWeight: FontWeight.w400,
    ),
    displayMedium: TextStyle(
      color: InkSlotColors.bone,
      fontFamily: 'Instrument Serif',
      fontSize: 44,
      height: 0.98,
      fontWeight: FontWeight.w400,
    ),
    displaySmall: TextStyle(
      color: InkSlotColors.bone,
      fontFamily: 'Instrument Serif',
      fontSize: 40,
      height: 1,
      fontWeight: FontWeight.w400,
    ),
    headlineMedium: TextStyle(
      color: InkSlotColors.bone,
      fontFamily: 'Instrument Serif',
      fontSize: 32,
      height: 1,
      fontWeight: FontWeight.w400,
    ),
    titleLarge: TextStyle(
      color: InkSlotColors.bone,
      fontSize: 20,
      height: 1.2,
      fontWeight: FontWeight.w500,
    ),
    bodyLarge: TextStyle(color: InkSlotColors.bone, fontSize: 16, height: 1.35),
    bodyMedium: TextStyle(
      color: InkSlotColors.secondary,
      fontSize: 15,
      height: 1.35,
    ),
    labelSmall: TextStyle(
      color: InkSlotColors.ash,
      fontFamily: 'Geist Mono',
      fontSize: 11,
      height: 1.1,
      letterSpacing: 1.32,
      fontWeight: FontWeight.w500,
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: InkSlotColors.copper,
      foregroundColor: InkSlotColors.ink,
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: const StadiumBorder(),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: InkSlotColors.secondary,
      minimumSize: const Size(
        InkSlotSpacing.minimumTapTarget,
        InkSlotSpacing.minimumTapTarget,
      ),
    ),
  ),
  dividerTheme: const DividerThemeData(color: InkSlotColors.line, thickness: 1),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
    },
  ),
);
