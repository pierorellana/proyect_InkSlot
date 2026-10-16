import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../domain/booking_request.dart';
import '../../domain/booking_request_status.dart';
import 'booking_request_status_chip.dart';

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
    final contact =
        request.client.contactValue ??
        request.client.email ??
        request.client.phone ??
        'Contacto pendiente';
    final channel = _channelLabel(request.client.contactChannel);
    final duration = _formatDuration(request.durationMinutes);

    return Semantics(
      button: true,
      label: 'Abrir solicitud de ${request.client.name}',
      child: Material(
        color: InkSlotColors.surface,
        borderRadius: BorderRadius.circular(InkSlotRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InkSlotRadii.card),
          focusColor: InkSlotColors.copperGlow,
          splashColor: InkSlotColors.copperGlow,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 540;
                final identity = _Identity(
                  request: request,
                  contact: contact,
                  channel: channel,
                  duration: duration,
                );
                final status = BookingRequestStatusChip(status: request.status);
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: identity),
                          const SizedBox(width: 12),
                          status,
                        ],
                      ),
                      const SizedBox(height: 18),
                      _RequestMeta(request: request),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: identity),
                    const SizedBox(width: 22),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        status,
                        const SizedBox(height: 18),
                        _RequestMeta(request: request),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.request,
    required this.contact,
    required this.channel,
    required this.duration,
  });

  final BookingRequest request;
  final String contact;
  final String channel;
  final String duration;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        request.client.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: InkSlotColors.cream,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 9),
      Row(
        children: [
          Icon(
            _channelIcon(request.client.contactChannel),
            size: 16,
            color: InkSlotColors.copperLight,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              '$channel · $contact',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InkSlotColors.secondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        duration,
        style: const TextStyle(
          color: InkSlotColors.ash,
          fontFamily: 'Geist Mono',
          fontSize: 11,
          letterSpacing: .5,
        ),
      ),
    ],
  );
}

class _RequestMeta extends StatelessWidget {
  const _RequestMeta({required this.request});

  final BookingRequest request;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.schedule_outlined, size: 16, color: InkSlotColors.ash),
      const SizedBox(width: 7),
      Text(
        'Creada ${_formatDate(request.createdAt)}',
        style: const TextStyle(color: InkSlotColors.ash, fontSize: 12),
      ),
      const SizedBox(width: 12),
      const Icon(
        Icons.arrow_forward,
        size: 17,
        color: InkSlotColors.copperLight,
      ),
    ],
  );
}

String _channelLabel(ContactChannel? channel) => switch (channel) {
  ContactChannel.whatsapp => 'WhatsApp',
  ContactChannel.instagram => 'Instagram',
  ContactChannel.email => 'Email',
  ContactChannel.phone => 'Teléfono',
  null => 'Contacto',
};

IconData _channelIcon(ContactChannel? channel) => switch (channel) {
  ContactChannel.whatsapp => Icons.chat_bubble_outline,
  ContactChannel.instagram => Icons.camera_alt_outlined,
  ContactChannel.email => Icons.mail_outline,
  ContactChannel.phone => Icons.phone_outlined,
  null => Icons.person_outline,
};

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder min de sesión';
  if (remainder == 0) return '$hours h de sesión';
  return '$hours h $remainder min de sesión';
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';
