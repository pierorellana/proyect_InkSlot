import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/inkslot_tokens.dart';

class InkSlotLogo extends StatelessWidget {
  const InkSlotLogo({
    super.key,
    this.color = InkSlotColors.bone,
    this.size = 64,
    this.semanticsLabel = 'Logo de InkSlot',
  });

  final Color color;
  final double size;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticsLabel,
    child: SvgPicture.asset(
      InkSlotAssets.logoBone,
      width: size,
      height: size * 1.3,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      excludeFromSemantics: true,
    ),
  );
}
