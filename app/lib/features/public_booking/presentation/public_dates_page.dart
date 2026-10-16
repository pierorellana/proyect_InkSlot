import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../domain/public_availability.dart';
import '../domain/public_reservation.dart';
import 'public_reservation_controller.dart';
import 'widgets/public_calendar.dart';
import 'widgets/public_state_panel.dart';
import 'widgets/public_time_wheel.dart';
import 'widgets/public_time_zone_formatter.dart';

class PublicDatesPage extends StatefulWidget {
  const PublicDatesPage({
    required this.token,
    required this.controller,
    super.key,
  });

  final String token;
  final PublicReservationController controller;

  @override
  State<PublicDatesPage> createState() => _PublicDatesPageState();
}

class _PublicDatesPageState extends State<PublicDatesPage> {
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _initialLoadScheduled = false;

  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant PublicDatesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _rangeStart = null;
      _rangeEnd = null;
      _initialLoadScheduled = false;
      _scheduleInitialLoad();
    }
  }

  void _scheduleInitialLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialLoadScheduled) return;
      _initialLoadScheduled = true;
      _loadFromReservation();
    });
  }

  void _loadFromReservation() {
    final status = widget.controller.reservationStatus;
    if (status == PublicReservationStatus.idle ||
        status == PublicReservationStatus.error) {
      widget.controller.loadReservation(widget.token);
      _initialLoadScheduled = false;
      return;
    }
    if (status != PublicReservationStatus.active) return;
    final range = _initialRange(widget.controller.reservation);
    _loadRange(range.$1, range.$2);
  }

  void _loadRange(DateTime start, DateTime end) {
    _rangeStart = start;
    _rangeEnd = end;
    widget.controller.loadAvailability(widget.token, start, end);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 34),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  _scheduleAvailabilityAfterSummary();
                  return _DatesContent(
                    controller: widget.controller,
                    rangeStart: _rangeStart,
                    rangeEnd: _rangeEnd,
                    onPrevious: _goPrevious,
                    onNext: _goNext,
                    onSelectDate: widget.controller.selectDate,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );

  void _scheduleAvailabilityAfterSummary() {
    if (_rangeStart != null ||
        _initialLoadScheduled ||
        widget.controller.reservationStatus != PublicReservationStatus.active ||
        widget.controller.availabilityStatus ==
            PublicAvailabilityStatus.loading ||
        widget.controller.availabilityStatus ==
            PublicAvailabilityStatus.ready ||
        widget.controller.availabilityStatus ==
            PublicAvailabilityStatus.empty ||
        widget.controller.availabilityStatus ==
            PublicAvailabilityStatus.error ||
        widget.controller.availabilityStatus ==
            PublicAvailabilityStatus.offline ||
        widget.controller.availabilityStatus ==
            PublicAvailabilityStatus.calendarUnavailable) {
      return;
    }
    _initialLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _rangeStart != null) return;
      final range = _initialRange(widget.controller.reservation);
      _loadRange(range.$1, range.$2);
    });
  }

  void _goPrevious() {
    final current = _rangeStart;
    final reservation = widget.controller.reservation;
    if (current == null || reservation == null) return;
    final lowerBound = _lowerBound(reservation);
    final nextStart = current.subtract(const Duration(days: 31));
    final start = nextStart.isBefore(lowerBound) ? lowerBound : nextStart;
    if (start.isAtSameMomentAs(current)) return;
    _loadRange(start, _rangeEndFor(start, reservation));
  }

  void _goNext() {
    final current = _rangeStart;
    final end = _rangeEnd;
    final reservation = widget.controller.reservation;
    if (current == null || end == null || reservation == null) return;
    final upperBound = _upperBound(reservation, current);
    if (!end.isBefore(upperBound)) return;
    final nextStart = current.add(const Duration(days: 31));
    final start = nextStart.isAfter(upperBound) ? upperBound : nextStart;
    _loadRange(start, _rangeEndFor(start, reservation));
  }
}

class _DatesContent extends StatelessWidget {
  const _DatesContent({
    required this.controller,
    required this.rangeStart,
    required this.rangeEnd,
    required this.onPrevious,
    required this.onNext,
    required this.onSelectDate,
  });

  final PublicReservationController controller;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final reservation = controller.reservation;
    final reservationStatus = controller.reservationStatus;
    if (reservation == null ||
        reservationStatus == PublicReservationStatus.loading ||
        reservationStatus == PublicReservationStatus.idle) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: PublicStatePanel(
          kind: PublicStateKind.loading,
          title: 'Cargando tu reserva',
          message: 'Estamos preparando tus fechas disponibles.',
        ),
      );
    }
    if (reservationStatus != PublicReservationStatus.active) {
      return Padding(
        padding: const EdgeInsets.only(top: 90),
        child: PublicStatePanel(
          kind: _reservationKind(reservationStatus),
          title: _reservationTitle(reservationStatus),
          message:
              controller.reservationError ??
              _reservationMessage(reservationStatus),
        ),
      );
    }

    final availabilityStatus = controller.availabilityStatus;
    if (availabilityStatus == PublicAvailabilityStatus.loading ||
        availabilityStatus == PublicAvailabilityStatus.idle) {
      return const Padding(
        padding: EdgeInsets.only(top: 90),
        child: PublicStatePanel(
          kind: PublicStateKind.loading,
          title: 'Buscando horarios',
          message: 'Consultando la agenda del estudio.',
        ),
      );
    }
    if (availabilityStatus != PublicAvailabilityStatus.ready ||
        controller.availability == null ||
        rangeStart == null ||
        rangeEnd == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 90),
        child: PublicStatePanel(
          kind: _availabilityKind(availabilityStatus),
          title: _availabilityTitle(availabilityStatus),
          message:
              controller.availabilityError ??
              _availabilityMessage(availabilityStatus),
          onRetry:
              availabilityStatus == PublicAvailabilityStatus.empty ||
                  availabilityStatus == PublicAvailabilityStatus.error ||
                  availabilityStatus == PublicAvailabilityStatus.offline ||
                  availabilityStatus ==
                      PublicAvailabilityStatus.calendarUnavailable
              ? controller.retryAvailability
              : null,
        ),
      );
    }

    final availability = controller.availability!;
    final selectedDay = controller.selectedDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Volver',
              constraints: const BoxConstraints(
                minWidth: InkSlotSpacing.minimumTapTarget,
                minHeight: InkSlotSpacing.minimumTapTarget,
              ),
            ),
            const Spacer(),
            InkSlotMonoLabel(
              'Duración ${_durationLabel(reservation.durationMinutes)}',
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text(
          'Elige tu fecha',
          style: TextStyle(
            color: InkSlotColors.cream,
            fontFamily: 'Instrument Serif',
            fontSize: 44,
            height: 1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Horarios en ${reservation.timezone}. Solo mostramos espacios verificables.',
          style: const TextStyle(
            color: InkSlotColors.secondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              onPressed: _canGoPrevious(rangeStart!, reservation)
                  ? onPrevious
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Rango anterior',
            ),
            IconButton(
              onPressed: _canGoNext(rangeStart!, rangeEnd!, reservation)
                  ? onNext
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Rango siguiente',
            ),
          ],
        ),
        PublicCalendar(
          rangeStart: rangeStart!,
          rangeEnd: rangeEnd!,
          availableDays: availability.days,
          selectedDate: selectedDay?.date,
          onSelectDate: onSelectDate,
        ),
        if (selectedDay != null) ...[
          const SizedBox(height: 28),
          const InkSlotMonoLabel(
            'Selecciona una hora',
            color: InkSlotColors.copperLight,
          ),
          const SizedBox(height: 4),
          Text(
            _dateLabel(selectedDay.date),
            style: const TextStyle(
              color: InkSlotColors.cream,
              fontFamily: 'Instrument Serif',
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 4),
          PublicTimeWheel(
            slots: selectedDay.slots,
            timezone: availability.timezone,
            selectedSlot: controller.selectedSlot,
            onSelected: controller.selectSlot,
          ),
          if (controller.selectedSlot != null)
            _SelectedSlotNotice(
              slot: controller.selectedSlot!,
              timezone: availability.timezone,
            ),
        ],
      ],
    );
  }
}

class _SelectedSlotNotice extends StatelessWidget {
  const _SelectedSlotNotice({required this.slot, required this.timezone});

  final AvailabilitySlot slot;
  final String timezone;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: 'Horario seleccionado ${_formatTime(slot.startAt, timezone)}',
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: InkSlotColors.tobacco,
        borderRadius: BorderRadius.circular(InkSlotRadii.chip),
        border: Border.all(color: InkSlotColors.copperGlow),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: InkSlotColors.copperLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Horario seleccionado · ${_formatTime(slot.startAt, timezone)}',
              style: const TextStyle(color: InkSlotColors.cream, fontSize: 15),
            ),
          ),
        ],
      ),
    ),
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

PublicStateKind _availabilityKind(PublicAvailabilityStatus status) =>
    switch (status) {
      PublicAvailabilityStatus.empty => PublicStateKind.empty,
      PublicAvailabilityStatus.calendarUnavailable =>
        PublicStateKind.calendarUnavailable,
      PublicAvailabilityStatus.offline => PublicStateKind.offline,
      _ => PublicStateKind.error,
    };

String _availabilityTitle(PublicAvailabilityStatus status) => switch (status) {
  PublicAvailabilityStatus.empty => 'No hay horarios disponibles',
  PublicAvailabilityStatus.calendarUnavailable => 'Agenda no verificable',
  PublicAvailabilityStatus.offline => 'Sin conexión',
  _ => 'No pudimos cargar los horarios',
};

String _availabilityMessage(PublicAvailabilityStatus status) =>
    switch (status) {
      PublicAvailabilityStatus.empty =>
        'Prueba otro rango o escribe al estudio para coordinar.',
      PublicAvailabilityStatus.calendarUnavailable =>
        'No mostraremos horarios hasta poder verificar la agenda del estudio.',
      PublicAvailabilityStatus.offline =>
        'Revisa tu conexión e intenta nuevamente.',
      _ => 'Intenta nuevamente en unos momentos.',
    };

(DateTime, DateTime) _initialRange(PublicReservation? reservation) {
  final today = _dateOnly(DateTime.now());
  final minDate = reservation?.restrictions.minDate;
  final maxDate = reservation?.restrictions.maxDate;
  var start = minDate != null && minDate.isAfter(today) ? minDate : today;
  if (maxDate != null && maxDate.isBefore(start)) start = maxDate;
  return (start, _rangeEndFor(start, reservation));
}

DateTime _lowerBound(PublicReservation reservation) {
  final today = _dateOnly(DateTime.now());
  final minDate = reservation.restrictions.minDate;
  return minDate != null && minDate.isAfter(today) ? minDate : today;
}

DateTime _upperBound(PublicReservation reservation, DateTime currentStart) =>
    reservation.restrictions.maxDate ??
    currentStart.add(const Duration(days: 30));

DateTime _rangeEndFor(DateTime start, PublicReservation? reservation) {
  final candidate = start.add(const Duration(days: 30));
  final maxDate = reservation?.restrictions.maxDate;
  return maxDate != null && maxDate.isBefore(candidate) ? maxDate : candidate;
}

bool _canGoPrevious(DateTime start, PublicReservation reservation) =>
    start.isAfter(_lowerBound(reservation));

bool _canGoNext(DateTime start, DateTime end, PublicReservation reservation) =>
    end.isBefore(_upperBound(reservation, start));

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dateLabel(DateTime value) {
  const weekdays = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${weekdays[value.weekday - 1]}, ${value.day} de ${months[value.month - 1]}';
}

String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return hours == 1 ? '1 hora' : '$hours horas';
  return '${hours}h ${remainder}m';
}

String _formatTime(DateTime utc, String timezone) {
  return formatPublicTime(utc, timezone);
}
