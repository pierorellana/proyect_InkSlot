import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../domain/booking_request_status.dart';

class BookingRequestStatusChip extends StatelessWidget {
  const BookingRequestStatusChip({required this.status, super.key});

  final BookingRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = _colors(status);
    return Semantics(
      label: 'Estado: $label',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(InkSlotRadii.chip),
          border: Border.all(color: foreground.withValues(alpha: .22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color, Color) _colors(BookingRequestStatus value) {
    return switch (value) {
      BookingRequestStatus.pending => (
        'Pendiente',
        InkSlotColors.copperLight,
        InkSlotColors.tobacco,
      ),
      BookingRequestStatus.booked => (
        'Agendada',
        InkSlotColors.successText,
        const Color(0xFF162119),
      ),
      BookingRequestStatus.expired => (
        'Vencida',
        InkSlotColors.warningText,
        const Color(0xFF272116),
      ),
      BookingRequestStatus.cancelled => (
        'Cancelada',
        InkSlotColors.errorText,
        const Color(0xFF2A1714),
      ),
      BookingRequestStatus.closed => (
        'Cerrada',
        InkSlotColors.secondary,
        InkSlotColors.surfaceTwo,
      ),
    };
  }
}
