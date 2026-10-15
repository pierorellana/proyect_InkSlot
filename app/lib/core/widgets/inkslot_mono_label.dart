import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';

class InkSlotMonoLabel extends StatelessWidget {
  const InkSlotMonoLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: color ?? InkSlotColors.ash),
  );
}
