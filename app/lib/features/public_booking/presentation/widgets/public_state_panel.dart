import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_mono_label.dart';
import '../../../../core/widgets/inkslot_primary_button.dart';

enum PublicStateKind {
  loading,
  expired,
  revoked,
  booked,
  calendarUnavailable,
  offline,
  empty,
  error,
}

class PublicStatePanel extends StatelessWidget {
  const PublicStatePanel({
    required this.kind,
    required this.title,
    required this.message,
    super.key,
    this.onRetry,
    this.onBack,
  });

  final PublicStateKind kind;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final icon = switch (kind) {
      PublicStateKind.loading => Icons.hourglass_empty_rounded,
      PublicStateKind.expired => Icons.schedule_rounded,
      PublicStateKind.revoked => Icons.link_off_rounded,
      PublicStateKind.booked => Icons.event_available_rounded,
      PublicStateKind.calendarUnavailable => Icons.event_busy_rounded,
      PublicStateKind.offline => Icons.wifi_off_rounded,
      PublicStateKind.empty => Icons.calendar_today_rounded,
      PublicStateKind.error => Icons.error_outline_rounded,
    };
    final accent = switch (kind) {
      PublicStateKind.loading => InkSlotColors.copper,
      PublicStateKind.empty => InkSlotColors.copper,
      PublicStateKind.booked => InkSlotColors.success,
      PublicStateKind.error || PublicStateKind.offline => InkSlotColors.error,
      _ => InkSlotColors.warning,
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : InkSlotMotion.micro,
        child: Container(
          key: ValueKey('$kind-$title'),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: InkSlotColors.surface,
            borderRadius: BorderRadius.circular(InkSlotRadii.card),
            border: Border.all(color: InkSlotColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: accent, size: 28),
              const SizedBox(height: 18),
              InkSlotMonoLabel(title, color: accent),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(
                  color: InkSlotColors.secondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              if (onRetry != null || onBack != null) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    if (onRetry != null)
                      Expanded(
                        child: InkSlotPrimaryButton(
                          label: 'Reintentar',
                          onPressed: onRetry,
                        ),
                      ),
                    if (onRetry != null && onBack != null)
                      const SizedBox(width: 10),
                    if (onBack != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onBack,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            foregroundColor: InkSlotColors.cream,
                            side: const BorderSide(
                              color: InkSlotColors.lineStrong,
                            ),
                          ),
                          child: const Text('Volver'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
