import 'package:flutter/material.dart';

abstract final class InkSlotColors {
  static const ink = Color(0xFF0A0A0B);
  static const deep = Color(0xFF050505);
  static const surface = Color(0xFF131315);
  static const bone = Color(0xFFEEE9E0);
  static const ash = Color(0xFF9B968E);
  static const copper = Color(0xFFC87939);
}

ThemeData buildInkSlotTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: InkSlotColors.deep,
  colorScheme: const ColorScheme.dark(
    surface: InkSlotColors.surface,
    primary: InkSlotColors.copper,
    onPrimary: InkSlotColors.ink,
    onSurface: InkSlotColors.bone,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: InkSlotColors.bone,
      fontSize: 40,
      height: 1,
    ),
    bodyLarge: TextStyle(color: InkSlotColors.bone, fontSize: 16),
    bodyMedium: TextStyle(color: InkSlotColors.ash, fontSize: 15),
  ),
);
