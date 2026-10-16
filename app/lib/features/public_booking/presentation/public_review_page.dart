import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_availability.dart';
import '../domain/public_reservation.dart';
import 'public_reservation_controller.dart';
import 'widgets/public_state_panel.dart';
import 'widgets/public_time_zone_formatter.dart';

class PublicReviewPage extends StatefulWidget {
  const PublicReviewPage({
    required this.token,
    required this.controller,
    required this.onBack,
    required this.onConfirmed,
    super.key,
  });

  final String token;
  final PublicReservationController controller;
  final VoidCallback onBack;
  final VoidCallback onConfirmed;

  @override
  State<PublicReviewPage> createState() => _PublicReviewPageState();
}

class _PublicReviewPageState extends State<PublicReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final status = widget.controller.reservationStatus;
      if (status == PublicReservationStatus.idle ||
          status == PublicReservationStatus.error) {
        widget.controller.loadReservation(widget.token);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PublicReviewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token == widget.token) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadReservation(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => _ReviewContent(
                controller: widget.controller,
                token: widget.token,
                onBack: widget.onBack,
                onConfirmed: widget.onConfirmed,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({
    required this.controller,
    required this.token,
    required this.onBack,
    required this.onConfirmed,
  });

  final PublicReservationController controller;
  final String token;
  final VoidCallback onBack;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context) {
    final reservation = controller.reservation;
    final reservationStatus = controller.reservationStatus;
    if (controller.token != token ||
        reservation == null ||
        reservationStatus == PublicReservationStatus.idle ||
        reservationStatus == PublicReservationStatus.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: PublicStatePanel(
          kind: PublicStateKind.loading,
          title: 'Cargando tu reserva',
          message: 'Estamos preparando tu ticket de revisión.',
        ),
      );
    }
    if (reservationStatus != PublicReservationStatus.active) {
      return _state(
        kind: _reservationKind(reservationStatus),
        title: _reservationTitle(reservationStatus),
        message:
            controller.reservationError ??
            _reservationMessage(reservationStatus),
        onRetry: reservationStatus == PublicReservationStatus.error
            ? controller.retryReservation
            : null,
        onBack: onBack,
      );
    }

    final slot = controller.selectedSlot;
    if (slot == null) {
      return _state(
        kind: PublicStateKind.empty,
        title: 'Elige un horario primero',
        message:
            'Vuelve a fechas para seleccionar el espacio que quieres reservar.',
        onBack: onBack,
      );
    }

    final confirmationStatus = controller.confirmationStatus;
    final showError =
        confirmationStatus != PublicConfirmationStatus.idle &&
        confirmationStatus != PublicConfirmationStatus.loading &&
        confirmationStatus != PublicConfirmationStatus.confirmed;
    final canConfirm = _canConfirm(confirmationStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewHeader(onBack: onBack),
        const SizedBox(height: 28),
        const Text(
          'Revisa tu espacio',
          style: TextStyle(
            color: InkSlotColors.cream,
            fontFamily: 'Instrument Serif',
            fontSize: 44,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Confirma que todo esté correcto antes de cerrar tu reserva.',
          style: TextStyle(
            color: InkSlotColors.secondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 26),
        _ReviewTicket(reservation: reservation, slot: slot),
        if (showError) ...[
          const SizedBox(height: 18),
          PublicStatePanel(
            kind: _confirmationKind(confirmationStatus),
            title: _confirmationTitle(confirmationStatus),
            message:
                controller.confirmationError ??
                _confirmationMessage(confirmationStatus),
            onRetry: _canRetry(confirmationStatus)
                ? controller.retryConfirmation
                : null,
            onBack: onBack,
          ),
        ],
        const SizedBox(height: 20),
        InkSlotPrimaryButton(
          label: confirmationStatus == PublicConfirmationStatus.loading
              ? 'Confirmando…'
              : 'Confirmar reserva',
          onPressed: canConfirm
              ? () async {
                  final confirmation = await controller.confirmSelected(token);
                  if (confirmation != null) onConfirmed();
                }
              : null,
          trailing: confirmationStatus == PublicConfirmationStatus.loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: InkSlotColors.ink,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 22),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onBack,
          child: const Text('Cambiar fecha u hora'),
        ),
      ],
    );
  }

  Widget _state({
    required PublicStateKind kind,
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onBack,
  }) => Padding(
    padding: const EdgeInsets.only(top: 90),
    child: PublicStatePanel(
      kind: kind,
      title: title,
      message: message,
      onRetry: onRetry,
      onBack: onBack,
    ),
  );
}

class _ReviewHeader extends StatelessWidget {
  const _ReviewHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Volver a fechas',
        constraints: const BoxConstraints(
          minWidth: InkSlotSpacing.minimumTapTarget,
          minHeight: InkSlotSpacing.minimumTapTarget,
        ),
      ),
      const Spacer(),
      const InkSlotMonoLabel('Paso 2 de 3', color: InkSlotColors.copperLight),
    ],
  );
}

class _ReviewTicket extends StatelessWidget {
  const _ReviewTicket({required this.reservation, required this.slot});

  final PublicReservation reservation;
  final AvailabilitySlot slot;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final angle = reduceMotion ? 0.0 : -0.025;
    return Semantics(
      container: true,
      label: 'Ticket de revisión para ${reservation.artistDisplayName}',
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: InkSlotColors.surface,
            borderRadius: BorderRadius.circular(InkSlotRadii.card),
            border: Border.all(color: InkSlotColors.copperGlow),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const InkSlotLogo(size: 42, color: InkSlotColors.copperLight),
                  const Spacer(),
                  const InkSlotMonoLabel(
                    'InkSlot · ticket',
                    color: InkSlotColors.copperLight,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                reservation.artistDisplayName,
                style: const TextStyle(
                  color: InkSlotColors.cream,
                  fontFamily: 'Instrument Serif',
                  fontSize: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: InkSlotColors.line),
              const SizedBox(height: 18),
              _TicketRow(
                label: 'Fecha',
                value: formatPublicDate(slot.startAt, reservation.timezone),
              ),
              const SizedBox(height: 14),
              _TicketRow(
                label: 'Hora',
                value:
                    '${formatPublicTime(slot.startAt, reservation.timezone)} — '
                    '${formatPublicTime(slot.endAt, reservation.timezone)}',
              ),
              const SizedBox(height: 14),
              _TicketRow(
                label: 'Duración',
                value: _durationLabel(reservation.durationMinutes),
              ),
              const SizedBox(height: 14),
              _TicketRow(label: 'Zona', value: reservation.timezone),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 86, child: InkSlotMonoLabel(label)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            color: InkSlotColors.cream,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    ],
  );
}

PublicStateKind _reservationKind(PublicReservationStatus status) =>
    switch (status) {
      PublicReservationStatus.expired => PublicStateKind.expired,
      PublicReservationStatus.revoked => PublicStateKind.revoked,
      PublicReservationStatus.booked => PublicStateKind.booked,
      _ => PublicStateKind.error,
    };

String _reservationTitle(PublicReservationStatus status) => switch (status) {
  PublicReservationStatus.expired => 'Este enlace expiró',
  PublicReservationStatus.revoked => 'Este enlace ya no está disponible',
  PublicReservationStatus.booked => 'Esta reserva ya está agendada',
  _ => 'No pudimos cargar la reserva',
};

String _reservationMessage(PublicReservationStatus status) => switch (status) {
  PublicReservationStatus.expired =>
    'Solicita un nuevo enlace al estudio para continuar.',
  PublicReservationStatus.revoked =>
    'Solicita al estudio que revise tu reserva.',
  PublicReservationStatus.booked =>
    'El horario de esta solicitud ya fue confirmado.',
  _ => 'Intenta nuevamente en unos momentos.',
};

PublicStateKind _confirmationKind(PublicConfirmationStatus status) =>
    switch (status) {
      PublicConfirmationStatus.conflict => PublicStateKind.conflict,
      PublicConfirmationStatus.alreadyBooked => PublicStateKind.alreadyBooked,
      PublicConfirmationStatus.expired => PublicStateKind.expired,
      PublicConfirmationStatus.revoked => PublicStateKind.revoked,
      PublicConfirmationStatus.calendarUnavailable =>
        PublicStateKind.calendarUnavailable,
      PublicConfirmationStatus.offline => PublicStateKind.offline,
      _ => PublicStateKind.error,
    };

String _confirmationTitle(PublicConfirmationStatus status) => switch (status) {
  PublicConfirmationStatus.conflict => 'Ese horario cambió',
  PublicConfirmationStatus.alreadyBooked => 'Esta reserva ya está agendada',
  PublicConfirmationStatus.expired => 'Este enlace expiró',
  PublicConfirmationStatus.revoked => 'Este enlace ya no está disponible',
  PublicConfirmationStatus.calendarUnavailable => 'Agenda no verificable',
  PublicConfirmationStatus.offline => 'Sin conexión',
  _ => 'No pudimos confirmar la reserva',
};

String _confirmationMessage(
  PublicConfirmationStatus status,
) => switch (status) {
  PublicConfirmationStatus.conflict =>
    'El espacio dejó de estar disponible. Regresa a fechas para elegir otro.',
  PublicConfirmationStatus.alreadyBooked =>
    'Esta solicitud ya tiene un horario confirmado.',
  PublicConfirmationStatus.expired => 'Solicita un nuevo enlace al estudio.',
  PublicConfirmationStatus.revoked =>
    'Solicita al estudio que revise tu reserva.',
  PublicConfirmationStatus.calendarUnavailable =>
    'No confirmaremos hasta poder verificar la agenda del estudio.',
  PublicConfirmationStatus.offline =>
    'Revisa tu conexión e intenta nuevamente.',
  _ => 'Intenta nuevamente en unos momentos.',
};

bool _canRetry(PublicConfirmationStatus status) =>
    status == PublicConfirmationStatus.calendarUnavailable ||
    status == PublicConfirmationStatus.offline ||
    status == PublicConfirmationStatus.error;

bool _canConfirm(PublicConfirmationStatus status) =>
    status == PublicConfirmationStatus.idle ||
    status == PublicConfirmationStatus.calendarUnavailable ||
    status == PublicConfirmationStatus.offline ||
    status == PublicConfirmationStatus.error;

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return hours == 1 ? '1 hora' : '$hours horas';
  return '${hours}h ${remainder}m';
}
