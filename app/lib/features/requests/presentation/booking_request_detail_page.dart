import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';
import 'booking_requests_controller.dart';
import 'widgets/booking_request_status_chip.dart';
import 'widgets/request_action_sheet.dart';

class BookingRequestDetailPage extends StatefulWidget {
  const BookingRequestDetailPage({
    required this.controller,
    required this.requestId,
    super.key,
  });

  final BookingRequestsController controller;
  final String requestId;

  @override
  State<BookingRequestDetailPage> createState() =>
      _BookingRequestDetailPageState();
}

class _BookingRequestDetailPageState extends State<BookingRequestDetailPage> {
  BookingRequestsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.loadDetail(widget.requestId);
    });
  }

  Future<void> _openActions(BookingRequest request) async {
    if (controller.mutationStatus == BookingRequestMutationStatus.submitting) {
      return;
    }
    final action = await RequestActionSheet.show(context, request);
    if (!mounted || action == null) return;
    final confirmed = await _confirm(action, request);
    if (!mounted || !confirmed) return;

    controller.clearError();
    switch (action) {
      case RequestAction.renew:
        {
          final link = await controller.renew(widget.requestId);
          if (!mounted || link == null) return;
          context.go('/admin/requests/link', extra: link);
        }
      case RequestAction.revoke:
        {
          await controller.revoke(widget.requestId);
          if (mounted && controller.mutationError == null) {
            await controller.loadDetail(widget.requestId);
          }
        }
      case RequestAction.close:
        {
          await controller.close(widget.requestId);
          if (mounted && controller.mutationError == null) {
            await controller.loadDetail(widget.requestId);
          }
        }
    }
  }

  Future<bool> _confirm(RequestAction action, BookingRequest request) async {
    final copy = switch (action) {
      RequestAction.renew => (
        '¿Renovar el enlace?',
        'El enlace actual dejará de funcionar y se generará uno nuevo para ${request.client.name}.',
        'Renovar enlace',
      ),
      RequestAction.revoke => (
        '¿Revocar la solicitud?',
        'El cliente ya no podrá acceder a este enlace de reserva.',
        'Revocar',
      ),
      RequestAction.close => (
        '¿Cerrar la solicitud?',
        'La solicitud quedará como cerrada y no podrá volver a cambiar de estado.',
        'Cerrar solicitud',
      ),
    };
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: InkSlotColors.sheet,
            title: Text(copy.$1),
            content: Text(
              copy.$2,
              style: const TextStyle(color: InkSlotColors.secondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: action == RequestAction.revoke
                      ? InkSlotColors.error
                      : InkSlotColors.copper,
                  foregroundColor: InkSlotColors.ink,
                ),
                child: Text(copy.$3),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final status = controller.detailStatus;
      if (status == BookingRequestDetailStatus.loading ||
          status == BookingRequestDetailStatus.idle) {
        return const _DetailLoading();
      }
      if (status == BookingRequestDetailStatus.error ||
          controller.detail == null) {
        return _DetailError(
          message: controller.detailError ?? 'No se pudo cargar el detalle.',
          onBack: () => context.go('/admin/requests'),
          onRetry: () => controller.loadDetail(widget.requestId),
        );
      }
      return _DetailContent(
        detail: controller.detail!,
        mutationStatus: controller.mutationStatus,
        mutationError: controller.mutationError,
        onBack: () => context.go('/admin/requests'),
        onActions: () => _openActions(controller.detail!.request),
      );
    },
  );
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.detail,
    required this.mutationStatus,
    required this.mutationError,
    required this.onBack,
    required this.onActions,
  });

  final BookingRequestDetail detail;
  final BookingRequestMutationStatus mutationStatus;
  final String? mutationError;
  final VoidCallback onBack;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final request = detail.request;
    final submitting =
        mutationStatus == BookingRequestMutationStatus.submitting;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DetailHeader(request: request, onBack: onBack),
              const SizedBox(height: 28),
              if (mutationError != null) ...[
                _MutationError(message: mutationError!),
                const SizedBox(height: 16),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 700;
                  final client = _ClientCard(request: request);
                  final reservation = _ReservationCard(detail: detail);
                  if (!wide) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        client,
                        const SizedBox(height: 14),
                        reservation,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: client),
                      const SizedBox(width: 14),
                      Expanded(child: reservation),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _AuditCard(entries: detail.audit),
              const SizedBox(height: 20),
              _ActionFooter(
                request: request,
                submitting: submitting,
                onActions: onActions,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.request, required this.onBack});

  final BookingRequest request;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InkSlotMonoLabel('Solicitudes · detalle'),
          const SizedBox(height: 14),
          Text(
            request.client.name,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Información administrativa y acciones de reserva.',
            style: TextStyle(color: InkSlotColors.secondary),
          ),
        ],
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BookingRequestStatusChip(status: request.status),
          const SizedBox(width: 10),
          IconButton(
            onPressed: onBack,
            tooltip: 'Volver a solicitudes',
            icon: const Icon(Icons.arrow_back),
          ),
        ],
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  tooltip: 'Volver a solicitudes',
                  icon: const Icon(Icons.arrow_back),
                ),
                const Spacer(),
                BookingRequestStatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: 12),
            identity,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: identity),
          const SizedBox(width: 18),
          actions,
        ],
      );
    },
  );
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.request});

  final BookingRequest request;

  @override
  Widget build(BuildContext context) {
    final client = request.client;
    final channel = _channelLabel(client.contactChannel);
    final contact =
        client.contactValue ?? client.email ?? client.phone ?? 'No registrado';
    return _InfoCard(
      eyebrow: 'Cliente',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(client.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          _DetailRow(
            icon: _channelIcon(client.contactChannel),
            label: channel,
            value: contact,
          ),
          const SizedBox(height: 15),
          _DetailRow(
            icon: Icons.verified_outlined,
            label: 'Anticipo',
            value: request.depositVerified ? 'Verificado' : 'Pendiente',
            valueColor: request.depositVerified
                ? InkSlotColors.successText
                : InkSlotColors.warningText,
          ),
          if (request.paymentReference != null) ...[
            const SizedBox(height: 15),
            _DetailRow(
              icon: Icons.receipt_long_outlined,
              label: 'Referencia',
              value: request.paymentReference!,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({required this.detail});

  final BookingRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final request = detail.request;
    return _InfoCard(
      eyebrow: 'Reserva',
      icon: Icons.event_available_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailRow(
            icon: Icons.timelapse_outlined,
            label: 'Duración',
            value: _formatDuration(request.durationMinutes),
          ),
          const SizedBox(height: 15),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Preferencias',
            value: _formatRestrictions(request),
          ),
          const SizedBox(height: 15),
          _LinkStatusRow(link: detail.currentLink),
        ],
      ),
    );
  }
}

class _LinkStatusRow extends StatelessWidget {
  const _LinkStatusRow({required this.link});

  final CurrentBookingLink? link;

  @override
  Widget build(BuildContext context) {
    final (label, value, color) = switch (link?.status) {
      BookingLinkStatus.active => (
        'Enlace',
        'Activo',
        InkSlotColors.successText,
      ),
      BookingLinkStatus.expired => (
        'Enlace',
        'Vencido',
        InkSlotColors.warningText,
      ),
      BookingLinkStatus.revoked => (
        'Enlace',
        'Revocado',
        InkSlotColors.errorText,
      ),
      BookingLinkStatus.consumed => (
        'Enlace',
        'Utilizado',
        InkSlotColors.copperLight,
      ),
      null => ('Enlace', 'Sin enlace activo', InkSlotColors.secondary),
    };
    return _DetailRow(
      icon: Icons.link_outlined,
      label: label,
      value: link == null
          ? value
          : '$value · vence ${_formatDateTime(link!.expiresAt)}',
      valueColor: color,
    );
  }
}

class _AuditCard extends StatelessWidget {
  const _AuditCard({required this.entries});

  final List<BookingRequestAuditEntry> entries;

  @override
  Widget build(BuildContext context) => _InfoCard(
    eyebrow: 'Historial',
    icon: Icons.history,
    child: entries.isEmpty
        ? const Text(
            'Aún no hay movimientos registrados.',
            style: TextStyle(color: InkSlotColors.secondary),
          )
        : Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _AuditRow(
                  entry: entries[index],
                  last: index == entries.length - 1,
                ),
                if (index != entries.length - 1) const SizedBox(height: 13),
              ],
            ],
          ),
  );
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry, required this.last});

  final BookingRequestAuditEntry entry;
  final bool last;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Column(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: InkSlotColors.copper,
              shape: BoxShape.circle,
            ),
          ),
          if (!last)
            Container(width: 1, height: 24, color: InkSlotColors.lineStrong),
        ],
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _auditLabel(entry.action),
              style: const TextStyle(
                color: InkSlotColors.cream,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatDateTime(entry.createdAt),
              style: const TextStyle(
                color: InkSlotColors.secondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ActionFooter extends StatelessWidget {
  const _ActionFooter({
    required this.request,
    required this.submitting,
    required this.onActions,
  });

  final BookingRequest request;
  final bool submitting;
  final VoidCallback onActions;

  @override
  Widget build(BuildContext context) {
    final canAct =
        request.status == BookingRequestStatus.pending ||
        request.status == BookingRequestStatus.expired;
    if (!canAct) {
      return Text(
        request.status == BookingRequestStatus.booked
            ? 'Esta solicitud ya fue agendada; sus acciones están bloqueadas.'
            : 'Esta solicitud está en un estado terminal.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: InkSlotColors.secondary),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSlotPrimaryButton(
          label: submitting ? 'Procesando…' : 'Acciones',
          onPressed: submitting ? null : onActions,
          trailing: submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: InkSlotColors.ink,
                  ),
                )
              : const Icon(Icons.more_horiz, size: 21),
        ),
        const SizedBox(height: 8),
        const Text(
          'Las acciones sensibles requieren confirmación.',
          textAlign: TextAlign.center,
          style: TextStyle(color: InkSlotColors.tertiary, fontSize: 12),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.eyebrow,
    required this.icon,
    required this.child,
  });

  final String eyebrow;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: InkSlotColors.copperLight, size: 19),
            const SizedBox(width: 9),
            Text(
              eyebrow.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: InkSlotColors.ash),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: InkSlotColors.tertiary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: valueColor ?? InkSlotColors.cream,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MutationError extends StatelessWidget {
  const _MutationError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF241614),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: InkSlotColors.error.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: InkSlotColors.errorText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: InkSlotColors.errorText),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailLoading extends StatelessWidget {
  const _DetailLoading();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(width: 160, height: 12, color: InkSlotColors.surfaceTwo),
        const SizedBox(height: 17),
        Container(width: 260, height: 42, color: InkSlotColors.surface),
        const SizedBox(height: 28),
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 156,
            decoration: BoxDecoration(
              color: InkSlotColors.surface,
              borderRadius: BorderRadius.circular(InkSlotRadii.card),
            ),
          ),
          if (index != 2) const SizedBox(height: 14),
        ],
      ],
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({
    required this.message,
    required this.onBack,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onBack;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: InkSlotColors.surface,
          borderRadius: BorderRadius.circular(InkSlotRadii.card),
          border: Border.all(color: InkSlotColors.line),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: InkSlotColors.errorText,
              size: 36,
            ),
            const SizedBox(height: 15),
            const Text(
              'No pudimos abrir esta solicitud',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: InkSlotColors.secondary),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton(onPressed: onBack, child: const Text('Volver')),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
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
  if (hours == 0) return '$remainder min';
  if (remainder == 0) return '$hours h';
  return '$hours h $remainder min';
}

String _formatRestrictions(BookingRequest request) {
  final parts = <String>[];
  if (request.minDate != null && request.maxDate != null) {
    parts.add(
      request.minDate == request.maxDate
          ? _formatDate(request.minDate!)
          : '${_formatDate(request.minDate!)} – ${_formatDate(request.maxDate!)}',
    );
  } else if (request.allowedWeekdays != null &&
      request.allowedWeekdays!.isNotEmpty) {
    parts.add('Días preferidos');
  }
  if (request.allowedWindows != null && request.allowedWindows!.isNotEmpty) {
    final window = request.allowedWindows!.first;
    parts.add('${window.startLocal}–${window.endLocal}');
  }
  return parts.isEmpty ? 'Sin restricciones' : parts.join(' · ');
}

String _auditLabel(String action) => switch (action) {
  'created' => 'Solicitud creada',
  'token_renewed' => 'Enlace renovado',
  'revoked' => 'Solicitud revocada',
  'closed' => 'Solicitud cerrada',
  _ => 'Actualización registrada',
};

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.year}';

String _formatDateTime(DateTime date) =>
    '${_formatDate(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
