import 'package:flutter/material.dart';

import '../../../../core/widgets/inkslot_kit.dart';
import '../../domain/booking_request_status.dart';

class BookingRequestStatusChip extends StatelessWidget {
  const BookingRequestStatusChip({required this.status, super.key});

  final BookingRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      BookingRequestStatus.pending => ('Pendiente', InkSlotPillTone.pending),
      BookingRequestStatus.booked => ('Agendada', InkSlotPillTone.ok),
      BookingRequestStatus.expired => ('Vencida', InkSlotPillTone.expired),
      BookingRequestStatus.cancelled => (
        'Cancelada',
        InkSlotPillTone.cancelled,
      ),
      BookingRequestStatus.closed => ('Cerrada', InkSlotPillTone.cancelled),
    };
    return Semantics(
      label: 'Estado: $label',
      container: true,
      excludeSemantics: true,
      child: InkSlotPill(label, tone: tone),
    );
  }
}
