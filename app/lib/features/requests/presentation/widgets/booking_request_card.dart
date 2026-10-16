import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_motion.dart';
import '../../domain/booking_request.dart';
import 'booking_request_status_chip.dart';

/// Fila de solicitud dentro de la tarjeta de lista del prototipo.
class BookingRequestCard extends StatelessWidget {
  const BookingRequestCard({
    required this.request,
    required this.onTap,
    super.key,
  });

  final BookingRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = request.client.name;
    final contact =
        request.client.contactValue ??
        request.client.email ??
        request.client.phone;
    final sub = [
      _formatDuration(request.durationMinutes),
      ?contact,
    ].join(' · ');
    return Semantics(
      button: true,
      label: 'Abrir solicitud de $name',
      excludeSemantics: true,
      child: InkSlotPress(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: InkSlotColors.surfaceTwo,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '·' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: InkSlotColors.bone,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InkSlotColors.bone,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InkSlotColors.ash,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BookingRequestStatusChip(status: request.status),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder min';
  if (remainder == 0) return '$hours h';
  return '$hours h $remainder min';
}
