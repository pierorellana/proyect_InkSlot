import 'package:flutter/material.dart';

abstract final class InkSlotColors {
  static const deep = Color(0xFF050505);
  static const ink = Color(0xFF0A0A0B);
  static const surface = Color(0xFF131315);
  static const surfaceTwo = Color(0xFF1C1C1F);
  static const elevated = Color(0xFF1F1E1C);
  static const field = Color(0xFF1A1A1D);
  static const sheet = Color(0xFF161618);

  static const bone = Color(0xFFEEE9E0);
  static const cream = Color(0xFFF2ECE2);
  static const secondary = Color(0xFFA7A29A);
  static const ash = Color(0xFF9B968E);
  static const tertiary = Color(0xFF8E8981);
  static const disabled = Color(0xFF4D4A46);

  static const copper = Color(0xFFC87939);
  static const copperLight = Color(0xFFD48A45);
  static const tobacco = Color(0xFF241A12);
  static const copperGlow = Color(0x29C87939);

  static const success = Color(0xFF8FBF9A);
  static const successText = Color(0xFFA9D3B2);
  static const warning = Color(0xFFE6C77A);
  static const warningText = Color(0xFFEDD497);
  static const error = Color(0xFFE2604C);
  static const errorText = Color(0xFFF08B78);

  static const lineSubtle = Color(0x0FEEE9E0);
  static const line = Color(0x14EEE9E0);
  static const lineStrong = Color(0x29EEE9E0);
}

abstract final class InkSlotRadii {
  static const button = 28.0;
  static const card = 24.0;
  static const sheet = 38.0;
  static const mosaic = 26.0;
  static const chip = 20.0;
}

abstract final class InkSlotSpacing {
  static const screenHorizontal = 20.0;
  static const screenHorizontalWide = 24.0;
  static const safeAreaTopReference = 58.0;
  static const safeAreaBottomReference = 34.0;
  static const minimumTapTarget = 44.0;
}

abstract final class InkSlotMotion {
  static const micro = Duration(milliseconds: 200);
  static const screen = Duration(milliseconds: 575);
  static const sheet = Duration(milliseconds: 550);
  static const splash = Duration(milliseconds: 4600);

  static const standard = Cubic(0.2, 0.8, 0.2, 1);
  static const sheetCurve = Cubic(0.2, 0.9, 0.25, 1);
  static const threeDimension = Cubic(0.16, 0.84, 0.3, 1);
  static const spring = Cubic(0.2, 1.3, 0.4, 1);
}

abstract final class InkSlotAssets {
  static const logoBone = 'assets/assets/logo/isotipo-D-hueso.svg';
  static const logoCopper = 'assets/assets/logo/isotipo-D-cobre.svg';
  static const logoInk = 'assets/assets/logo/isotipo-D-tinta.svg';
  static const lockupBone = 'assets/assets/logo/lockup-hueso.svg';

  static const flashes = <String>[
    'assets/assets/illustrations/flash-rosa.svg',
    'assets/assets/illustrations/flash-daga.svg',
    'assets/assets/illustrations/flash-ojo.svg',
    'assets/assets/illustrations/flash-luna.svg',
    'assets/assets/illustrations/flash-corazon.svg',
    'assets/assets/illustrations/flash-polilla.svg',
  ];
}
