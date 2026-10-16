import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_appointment.dart';
import '../domain/public_confirmation.dart';
import 'public_reservation_controller.dart';
import 'widgets/public_state_panel.dart';
import 'widgets/public_time_zone_formatter.dart';

class PublicResultPage extends StatefulWidget {
  const PublicResultPage({
    required this.token,
    required this.controller,
    required this.onReturnToDates,
    super.key,
  });

  final String token;
  final PublicReservationController controller;
  final VoidCallback onReturnToDates;

  @override
  State<PublicResultPage> createState() => _PublicResultPageState();
}

class _PublicResultPageState extends State<PublicResultPage> {
  @override
  void initState() {
    super.initState();
    _loadDeepLinkAppointment();
  }

  @override
  void didUpdateWidget(covariant PublicResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _loadDeepLinkAppointment();
  }

  void _loadDeepLinkAppointment() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = widget.controller;
      if (controller.token != widget.token ||
          controller.confirmation == null &&
              controller.appointment == null &&
              controller.confirmationStatus == PublicConfirmationStatus.idle) {
        controller.loadAppointment(widget.token);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 34),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) => _ResultContent(
                controller: widget.controller,
                token: widget.token,
                onReturnToDates: widget.onReturnToDates,
                onReload: widget.controller.retryAppointment,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.controller,
    required this.token,
    required this.onReturnToDates,
    required this.onReload,
  });

  final PublicReservationController controller;
  final String token;
  final VoidCallback onReturnToDates;
  final Future<void> Function() onReload;

  @override
  Widget build(BuildContext context) {
    final confirmation = controller.confirmation;
    final appointment = controller.appointment;
    final status = controller.confirmationStatus;
    if (controller.token != token ||
        (confirmation == null && appointment == null)) {
      if (controller.token != token ||
          status == PublicConfirmationStatus.loading ||
          status == PublicConfirmationStatus.idle) {
        return const Padding(
          padding: EdgeInsets.only(top: 90),
          child: PublicStatePanel(
            kind: PublicStateKind.loading,
            title: 'Buscando tu reserva',
            message: 'Estamos verificando el resultado de tu confirmación.',
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(top: 90),
        child: PublicStatePanel(
          kind: _stateKind(status),
          title: _stateTitle(status),
          message: controller.confirmationError ?? _stateMessage(status),
          onRetry: _canRetry(status) ? onReload : null,
          onBack: onReturnToDates,
        ),
      );
    }

    final data = _ResultData.from(
      confirmation: confirmation,
      appointment: appointment,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ResultMark(),
        const SizedBox(height: 24),
        const Center(
          child: InkSlotMonoLabel(
            'Reserva confirmada',
            color: InkSlotColors.successText,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Tu espacio está apartado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: InkSlotColors.cream,
            fontFamily: 'Instrument Serif',
            fontSize: 44,
            height: 1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _syncMessage(data.syncStatus),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: InkSlotColors.secondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        _ResultTicket(data: data),
        const SizedBox(height: 20),
        InkSlotPrimaryButton(
          label: 'Ver mi reserva',
          onPressed: onReload,
          trailing: const Icon(Icons.refresh_rounded, size: 21),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onReturnToDates,
          child: const Text('Volver a fechas'),
        ),
      ],
    );
  }
}

class _ResultMark extends StatelessWidget {
  const _ResultMark();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      image: true,
      label: 'Reserva confirmada',
      child: AnimatedContainer(
        duration: reduceMotion ? Duration.zero : InkSlotMotion.screen,
        curve: InkSlotMotion.threeDimension,
        width: 112,
        height: 112,
        margin: const EdgeInsets.symmetric(horizontal: 120),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: InkSlotColors.tobacco,
          border: Border.all(color: InkSlotColors.copper, width: 2),
          boxShadow: const [
            BoxShadow(
              color: InkSlotColors.copperGlow,
              blurRadius: 34,
              spreadRadius: 8,
            ),
          ],
        ),
        child: const Center(
          child: InkSlotLogo(size: 48, color: InkSlotColors.copperLight),
        ),
      ),
    );
  }
}

class _ResultTicket extends StatelessWidget {
  const _ResultTicket({required this.data});

  final _ResultData data;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Resumen de tu reserva confirmada',
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: InkSlotColors.surface,
        borderRadius: BorderRadius.circular(InkSlotRadii.card),
        border: Border.all(color: InkSlotColors.line),
      ),
      child: Column(
        children: [
          _ResultRow(
            label: 'Fecha',
            value: formatPublicDate(data.startAt, data.timezone),
          ),
          const SizedBox(height: 16),
          _ResultRow(
            label: 'Hora',
            value:
                '${formatPublicTime(data.startAt, data.timezone)} — '
                '${formatPublicTime(data.endAt, data.timezone)}',
          ),
          const SizedBox(height: 16),
          _ResultRow(label: 'Zona', value: data.timezone),
          const SizedBox(height: 16),
          _ResultRow(
            label: 'Sincronización',
            value: _syncLabel(data.syncStatus),
          ),
        ],
      ),
    ),
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 110, child: InkSlotMonoLabel(label)),
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

class _ResultData {
  const _ResultData({
    required this.status,
    required this.syncStatus,
    required this.startAt,
    required this.endAt,
    required this.timezone,
  });

  final String status;
  final String syncStatus;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;

  factory _ResultData.from({
    PublicConfirmation? confirmation,
    PublicAppointment? appointment,
  }) {
    final status = confirmation?.status ?? appointment!.status;
    final syncStatus = confirmation?.syncStatus ?? appointment!.syncStatus;
    final startAt = confirmation?.startAt ?? appointment!.startAt;
    final endAt = confirmation?.endAt ?? appointment!.endAt;
    final timezone = confirmation?.timezone ?? appointment!.timezone;
    return _ResultData(
      status: status,
      syncStatus: syncStatus,
      startAt: startAt,
      endAt: endAt,
      timezone: timezone,
    );
  }
}

PublicStateKind _stateKind(PublicConfirmationStatus status) => switch (status) {
  PublicConfirmationStatus.conflict => PublicStateKind.conflict,
  PublicConfirmationStatus.alreadyBooked => PublicStateKind.alreadyBooked,
  PublicConfirmationStatus.expired => PublicStateKind.expired,
  PublicConfirmationStatus.revoked => PublicStateKind.revoked,
  PublicConfirmationStatus.calendarUnavailable =>
    PublicStateKind.calendarUnavailable,
  PublicConfirmationStatus.offline => PublicStateKind.offline,
  _ => PublicStateKind.error,
};

String _stateTitle(PublicConfirmationStatus status) => switch (status) {
  PublicConfirmationStatus.conflict => 'Ese horario ya no está disponible',
  PublicConfirmationStatus.alreadyBooked => 'Esta reserva ya está agendada',
  PublicConfirmationStatus.expired => 'Este enlace expiró',
  PublicConfirmationStatus.revoked => 'Este enlace ya no está disponible',
  PublicConfirmationStatus.calendarUnavailable => 'Agenda no verificable',
  PublicConfirmationStatus.offline => 'Sin conexión',
  _ => 'No pudimos cargar tu reserva',
};

String _stateMessage(PublicConfirmationStatus status) => switch (status) {
  PublicConfirmationStatus.conflict =>
    'Regresa a fechas para elegir otro espacio.',
  PublicConfirmationStatus.alreadyBooked =>
    'La solicitud ya tiene una cita confirmada.',
  PublicConfirmationStatus.expired => 'Solicita un nuevo enlace al estudio.',
  PublicConfirmationStatus.revoked =>
    'Solicita al estudio que revise tu reserva.',
  PublicConfirmationStatus.calendarUnavailable =>
    'No mostraremos datos hasta poder verificar la agenda.',
  PublicConfirmationStatus.offline =>
    'Revisa tu conexión e intenta nuevamente.',
  _ => 'Intenta nuevamente en unos momentos.',
};

bool _canRetry(PublicConfirmationStatus status) =>
    status == PublicConfirmationStatus.offline ||
    status == PublicConfirmationStatus.calendarUnavailable ||
    status == PublicConfirmationStatus.error;

String _syncLabel(String status) => switch (status) {
  'synced' => 'Sincronizada',
  'failed' => 'Pendiente de sincronizar',
  _ => 'En proceso',
};

String _syncMessage(String status) => switch (status) {
  'synced' => 'Tu reserva ya está sincronizada con el calendario del estudio.',
  'failed' => 'Tu reserva está confirmada; el estudio volverá a sincronizarla.',
  _ => 'Tu reserva está confirmada. El estudio terminará la sincronización.',
};
