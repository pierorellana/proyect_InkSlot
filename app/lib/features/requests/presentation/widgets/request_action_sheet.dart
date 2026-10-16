import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../domain/booking_request.dart';
import '../../domain/booking_request_status.dart';

enum RequestAction { renew, revoke, close }

class RequestActionSheet extends StatelessWidget {
  const RequestActionSheet({required this.request, super.key});

  final BookingRequest request;

  static Future<RequestAction?> show(
    BuildContext context,
    BookingRequest request,
  ) => showModalBottomSheet<RequestAction>(
    context: context,
    backgroundColor: InkSlotColors.sheet,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(InkSlotRadii.sheet),
      ),
    ),
    builder: (_) => RequestActionSheet(request: request),
  );

  @override
  Widget build(BuildContext context) {
    final canChange =
        request.status == BookingRequestStatus.pending ||
        request.status == BookingRequestStatus.expired;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: InkSlotColors.lineStrong,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Acciones de solicitud',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 7),
            Text(
              request.client.name,
              style: const TextStyle(color: InkSlotColors.secondary),
            ),
            const SizedBox(height: 22),
            _ActionTile(
              icon: Icons.refresh_rounded,
              label: 'Renovar enlace',
              description: 'Revoca el enlace anterior y crea uno nuevo.',
              enabled: canChange,
              onTap: canChange
                  ? () => Navigator.pop(context, RequestAction.renew)
                  : null,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.link_off_outlined,
              label: 'Revocar solicitud',
              description: 'El enlace dejará de estar disponible.',
              enabled: canChange,
              destructive: true,
              onTap: canChange
                  ? () => Navigator.pop(context, RequestAction.revoke)
                  : null,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.archive_outlined,
              label: 'Cerrar solicitud',
              description: 'Marca esta solicitud como cerrada.',
              enabled: canChange,
              onTap: canChange
                  ? () => Navigator.pop(context, RequestAction.close)
                  : null,
            ),
            if (!canChange) ...[
              const SizedBox(height: 16),
              const Text(
                'Esta solicitud ya no admite acciones de ciclo de vida.',
                textAlign: TextAlign.center,
                style: TextStyle(color: InkSlotColors.tertiary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.enabled,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool enabled;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? InkSlotColors.errorText
        : InkSlotColors.copperLight;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled
            ? InkSlotColors.surface
            : InkSlotColors.surface.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: enabled ? color : InkSlotColors.disabled,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: enabled
                              ? InkSlotColors.cream
                              : InkSlotColors.disabled,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          color: enabled
                              ? InkSlotColors.secondary
                              : InkSlotColors.disabled,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: enabled ? InkSlotColors.ash : InkSlotColors.disabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
