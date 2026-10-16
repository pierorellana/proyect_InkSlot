import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_kit.dart';
import '../../../../core/widgets/inkslot_primary_button.dart';
import '../../domain/booking_request.dart';

enum RequestAction { renew, revoke, close }

/// Hoja de confirmación `.sheet` con grabber, titular serif, `.btn-d` y `.btn-g`.
class RequestActionSheet extends StatelessWidget {
  const RequestActionSheet({
    required this.action,
    required this.request,
    super.key,
  });

  final RequestAction action;
  final BookingRequest request;

  /// Devuelve `true` si la persona confirma la acción.
  static Future<bool> confirm(
    BuildContext context,
    RequestAction action,
    BookingRequest request,
  ) async =>
      await showInkSlotSheet<bool>(
        context: context,
        builder: (_) => RequestActionSheet(action: action, request: request),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final (title, body, cta, keep) = switch (action) {
      RequestAction.renew => (
        '¿Renovar el enlace de ${_first(request.client.name)}?',
        'El enlace actual dejará de funcionar y se generará uno nuevo.',
        'Renovar enlace',
        'Volver',
      ),
      RequestAction.revoke => (
        '¿Revocar el enlace?',
        'El cliente ya no podrá reservar con él. La solicitud y el anticipo siguen registrados.',
        'Revocar enlace',
        'Volver',
      ),
      RequestAction.close => (
        '¿Cerrar la solicitud?',
        'Quedará como cerrada manualmente y su enlace dejará de funcionar. El registro del anticipo no se borra.',
        'Cerrar solicitud',
        'Volver',
      ),
    };
    return Semantics(
      container: true,
      label: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: inkSlotSerif(32, height: 1.02)),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: InkSlotColors.secondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          if (action == RequestAction.renew)
            InkSlotPrimaryButton(
              label: cta,
              onPressed: () => Navigator.pop(context, true),
            )
          else
            InkSlotDangerButton(
              label: cta,
              onPressed: () => Navigator.pop(context, true),
            ),
          const SizedBox(height: 10),
          InkSlotGhostButton(
            label: keep,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

String _first(String name) => name.trim().split(' ').first;
