import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_reservation.dart';
import 'public_reservation_controller.dart';
import 'widgets/flash_mosaic.dart';
import 'widgets/public_state_panel.dart';

class PublicWelcomePage extends StatefulWidget {
  const PublicWelcomePage({
    required this.token,
    required this.onChooseDate,
    required this.controller,
    super.key,
  });

  final String token;
  final VoidCallback onChooseDate;
  final PublicReservationController controller;

  @override
  State<PublicWelcomePage> createState() => _PublicWelcomePageState();
}

class _PublicWelcomePageState extends State<PublicWelcomePage> {
  @override
  void initState() {
    super.initState();
    _loadReservation();
  }

  @override
  void didUpdateWidget(covariant PublicWelcomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) _loadReservation();
  }

  void _loadReservation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.loadReservation(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: SafeArea(
      bottom: true,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 34),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth >= 720 ? 560 : 560,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FlashMosaic(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) => _WelcomeContent(
                        controller: widget.controller,
                        onChooseDate: widget.onChooseDate,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({required this.controller, required this.onChooseDate});

  final PublicReservationController controller;
  final VoidCallback onChooseDate;

  @override
  Widget build(BuildContext context) {
    final reservation = controller.reservation;
    final status = controller.reservationStatus;
    if (reservation == null ||
        status == PublicReservationStatus.loading ||
        status == PublicReservationStatus.idle) {
      return const Padding(
        padding: EdgeInsets.only(top: 4),
        child: PublicStatePanel(
          kind: PublicStateKind.loading,
          title: 'Cargando tu reserva',
          message: 'Estamos preparando los detalles de tu enlace privado.',
        ),
      );
    }

    if (status != PublicReservationStatus.active) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: PublicStatePanel(
          kind: _stateKind(status),
          title: _stateTitle(status),
          message: controller.reservationError ?? _stateMessage(status),
          onRetry: status == PublicReservationStatus.error
              ? controller.retryReservation
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: InkSlotColors.copper,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            InkSlotMonoLabel(
              'Reserva abierta · ${_expiryLabel(reservation.expiresAt)}',
              color: InkSlotColors.copperLight,
            ),
          ],
        ),
        const SizedBox(height: 26),
        Text.rich(
          TextSpan(
            text: '${reservation.artistDisplayName},\n',
            children: const [
              TextSpan(
                text: 'tu espacio te espera.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          style: const TextStyle(
            color: InkSlotColors.cream,
            fontFamily: 'Instrument Serif',
            fontSize: 44,
            height: 0.98,
          ),
        ),
        const SizedBox(height: 28),
        _SummaryCard(reservation: reservation),
        const SizedBox(height: 24),
        _ArtistRow(reservation: reservation),
        const SizedBox(height: 28),
        InkSlotPrimaryButton(
          label: 'Elegir fecha y hora',
          onPressed: onChooseDate,
          trailing: const Icon(Icons.arrow_forward, size: 22),
        ),
        const SizedBox(height: 12),
        const TextButton(
          onPressed: null,
          child: Text('¿Dudas? Escríbele al estudio'),
        ),
      ],
    );
  }

  PublicStateKind _stateKind(PublicReservationStatus status) =>
      switch (status) {
        PublicReservationStatus.expired => PublicStateKind.expired,
        PublicReservationStatus.revoked => PublicStateKind.revoked,
        PublicReservationStatus.booked => PublicStateKind.booked,
        _ => PublicStateKind.error,
      };

  String _stateTitle(PublicReservationStatus status) => switch (status) {
    PublicReservationStatus.expired => 'Este enlace expiró',
    PublicReservationStatus.revoked => 'Este enlace ya no está disponible',
    PublicReservationStatus.booked => 'Esta reserva ya está agendada',
    _ => 'No pudimos cargar la reserva',
  };

  String _stateMessage(PublicReservationStatus status) => switch (status) {
    PublicReservationStatus.expired =>
      'Solicita un nuevo enlace al estudio para continuar.',
    PublicReservationStatus.revoked =>
      'Solicita al estudio que revise el estado de tu reserva.',
    PublicReservationStatus.booked =>
      'El horario de esta solicitud ya fue confirmado.',
    _ => 'Intenta nuevamente en unos momentos.',
  };
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.reservation});

  final PublicReservation reservation;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              label: 'Sesión',
              value: _durationLabel(reservation.durationMinutes),
            ),
          ),
          const VerticalDivider(width: 1, color: InkSlotColors.line),
          const Expanded(
            child: _SummaryItem(
              label: 'Anticipo',
              value: 'Validado ✓',
              valueColor: InkSlotColors.successText,
            ),
          ),
          const VerticalDivider(width: 1, color: InkSlotColors.line),
          Expanded(
            child: _SummaryItem(
              label: 'Días',
              value: _restrictionDays(reservation.restrictions.allowedWeekdays),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 16, 12, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkSlotMonoLabel(label),
        const SizedBox(height: 9),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? InkSlotColors.cream,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.reservation});

  final PublicReservation reservation;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 54,
        height: 54,
        decoration: const BoxDecoration(
          color: InkSlotColors.tobacco,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _initial(reservation.artistDisplayName),
          style: const TextStyle(
            color: InkSlotColors.bone,
            fontFamily: 'Instrument Serif',
            fontSize: 32,
          ),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reservation.artistDisplayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InkSlotColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Hasta ${_expiryLabel(reservation.expiresAt)} · ${reservation.timezone}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: InkSlotColors.secondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return hours == 1 ? '1 hora' : '$hours horas';
  return '${hours}h ${remainder}m';
}

String _restrictionDays(List<int>? weekdays) {
  if (weekdays == null || weekdays.isEmpty) return 'Flexible';
  const labels = <String>['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  final selected = weekdays.toList()..sort();
  if (selected.length == 7) return 'Todos';
  return selected.map((day) => labels[day]).join(' – ');
}

String _expiryLabel(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}';

String _initial(String value) =>
    value.trim().isEmpty ? '·' : value.trim()[0].toUpperCase();
