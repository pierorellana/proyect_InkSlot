import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';
import 'inkslot_motion.dart';

/// `.btn-p`: 56 px, radio 28, cobre, sombra `0 12 32 -12 rgba(200,121,57,.55)`.
class InkSlotPrimaryButton extends StatefulWidget {
  const InkSlotPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.trailing,
    this.leading,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? trailing;
  final Widget? leading;
  final bool loading;

  @override
  State<InkSlotPrimaryButton> createState() => _InkSlotPrimaryButtonState();
}

class _InkSlotPrimaryButtonState extends State<InkSlotPrimaryButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Opacity(
        opacity: widget.onPressed == null ? .28 : 1,
        child: InkSlotPress(
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _hover && enabled
                  ? InkSlotColors.copperLight
                  : InkSlotColors.copper,
              borderRadius: BorderRadius.circular(InkSlotRadii.button),
              boxShadow: widget.onPressed == null
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x8CC87939),
                        blurRadius: 32,
                        spreadRadius: -12,
                        offset: Offset(0, 12),
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: const TextStyle(
                fontFamily: 'Geist',
                color: InkSlotColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              child: IconTheme(
                data: const IconThemeData(color: InkSlotColors.ink),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.loading) ...[
                      const InkSlotSpinner(),
                      const SizedBox(width: 10),
                    ] else if (widget.leading != null) ...[
                      widget.leading!,
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.trailing != null && !widget.loading) ...[
                      const SizedBox(width: 10),
                      widget.trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
