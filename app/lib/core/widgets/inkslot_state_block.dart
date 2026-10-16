import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';
import 'inkslot_icon.dart';
import 'inkslot_kit.dart';
import 'inkslot_motion.dart';
import 'inkslot_primary_button.dart';

enum InkSlotStateTone { neutral, warning, error, success }

/// Estado vacío / error del prototipo (`Estados.dc.html`): disco de icono con
/// resplandor, titular serif, texto y acción.
class InkSlotStateBlock extends StatelessWidget {
  const InkSlotStateBlock({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
    this.tone = InkSlotStateTone.neutral,
    this.actionLabel,
    this.onAction,
    this.primary = true,
  });

  final InkSlotIcons icon;
  final String title;
  final String body;
  final InkSlotStateTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      InkSlotStateTone.neutral => InkSlotColors.bone,
      InkSlotStateTone.warning => InkSlotColors.warning,
      InkSlotStateTone.error => InkSlotColors.error,
      InkSlotStateTone.success => InkSlotColors.success,
    };
    return Semantics(
      container: true,
      liveRegion: tone == InkSlotStateTone.error,
      child: Padding(
        padding: const EdgeInsets.only(top: 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: InkSlotColors.surface,
                  border: Border.all(color: InkSlotColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .16),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: InkSlotIcon(icon, size: 30, color: color),
              ),
            ),
            const SizedBox(height: 36),
            Text(title, style: inkSlotSerif(34, height: 1.05)),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(
                color: InkSlotColors.secondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 22),
              if (primary)
                InkSlotPrimaryButton(label: actionLabel!, onPressed: onAction)
              else
                InkSlotGhostButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Esqueleto con pulso (`.live`) para listas y detalles en carga.
class InkSlotSkeletonBar extends StatelessWidget {
  const InkSlotSkeletonBar({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 7,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: InkSlotColors.surfaceTwo,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Fila esqueleto de lista (avatar + dos líneas + pill).
class InkSlotSkeletonRows extends StatelessWidget {
  const InkSlotSkeletonRows({super.key, this.count = 4, this.avatar = 44});

  final int count;
  final double avatar;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Cargando',
    child: InkSlotPulse(
      child: InkSlotCard(
        child: Column(
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const InkSlotSep(indent: 0),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    InkSlotSkeletonBar(
                      width: avatar,
                      height: avatar,
                      radius: avatar / 2.2,
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkSlotSkeletonBar(width: 130, height: 15),
                          SizedBox(height: 8),
                          InkSlotSkeletonBar(width: 90, height: 12),
                        ],
                      ),
                    ),
                    const InkSlotSkeletonBar(width: 76, height: 24, radius: 12),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
