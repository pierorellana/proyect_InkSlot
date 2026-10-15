import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';

class InkSlotPage extends StatelessWidget {
  const InkSlotPage({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(
      InkSlotSpacing.screenHorizontal,
      24,
      InkSlotSpacing.screenHorizontal,
      InkSlotSpacing.safeAreaBottomReference,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ColoredBox(
      color: InkSlotColors.deep,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: padding,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth >= 720 ? 560 : 560,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
