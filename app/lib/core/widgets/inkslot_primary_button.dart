import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';

class InkSlotPrimaryButton extends StatelessWidget {
  const InkSlotPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        shadowColor: InkSlotColors.copper,
        elevation: onPressed == null ? 0 : 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    ),
  );
}
