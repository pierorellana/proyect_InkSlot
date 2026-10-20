import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_availability.dart';
import '../domain/public_reservation.dart';
import 'public_reservation_controller.dart';
import 'public_studio_link.dart';
import 'widgets/public_calendar.dart';
import 'widgets/public_chrome.dart';
import 'widgets/public_format.dart';
import 'widgets/public_time_wheel.dart';

class PublicDatesPage extends StatefulWidget {
  const PublicDatesPage({
    required this.token,
    required this.controller,
    super.key,
    this.onReview,
    this.onBack,
  });

  final String token;
  final PublicReservationController controller;
  final VoidCallback? onReview;

  /// Volver a la bienvenida; por defecto va a `/r/:token` o hace `pop`.
  final VoidCallback? onBack;

  @override
  State<PublicDatesPage> createState() => _PublicDatesPageState();
}

class _PublicDatesPageState extends State<PublicDatesPage> {
  int _step = 0;
  DateTime? _month;
  bool _initialLoadScheduled = false;
  DateTime? _pickedDate;

  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant PublicDatesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token) {
      _month = null;
      _step = 0;
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
    _loadMonth(_initialMonth(widget.controller.reservation));
  }

  void _loadMonth(DateTime month) {
    final reservation = widget.controller.reservation;
    final lower = _lowerBound(reservation);
    final first = DateTime(month.year, month.month);
    final start = first.isBefore(lower) ? lower : first;
    final last = DateTime(month.year, month.month + 1, 0);
    final maxDate = reservation?.restrictions.maxDate;
    final end = maxDate != null && maxDate.isBefore(last) ? maxDate : last;
    setState(() {
      _month = first;
      _step = 0;
    });
    widget.controller.loadAvailability(widget.token, start, end);
  }

  void _scheduleAvailabilityAfterSummary() {
    final controller = widget.controller;
    if (_month != null ||
        _initialLoadScheduled ||
        controller.reservationStatus != PublicReservationStatus.active ||
        controller.availabilityStatus != PublicAvailabilityStatus.idle) {
      return;
    }
    _initialLoadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _month != null) return;
      _loadMonth(_initialMonth(widget.controller.reservation));
    });
  }

  void _goBack() {
    if (_step == 1) {
      setState(() => _step = 0);
      return;
    }
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/r/${widget.token}');
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _changeMonth(int delta) {
    final month = _month;
    if (month == null) return;
    _loadMonth(DateTime(month.year, month.month + delta));
  }

  void _showTimes() {
    final day = widget.controller.selectedDay;
    if (day == null) return;
    setState(() {
      _pickedDate = day.date;
      _step = 1;
    });
  }

  @override
  Widget build(BuildContext context) => PublicScreen(
    animateIn: false,
    builder: (context, safe) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        _scheduleAvailabilityAfterSummary();
        return _content(context, safe);
      },
    ),
  );

  Widget _content(BuildContext context, EdgeInsets safe) {
    final controller = widget.controller;
    final reservation = controller.reservation;
    final status = controller.reservationStatus;
    if (reservation == null ||
        status == PublicReservationStatus.loading ||
        status == PublicReservationStatus.idle) {
      return _FramedScreen(
        safe: safe,
        step: 1,
        onBack: _goBack,
        backLabel: 'Volver',
        child: const PublicBottomAligned(
          alignment: Alignment.bottomLeft,
          child: PublicTag(
            'Cargando tu reserva',
            color: InkSlotColors.copper,
            live: true,
          ),
        ),
      );
    }
    if (status == PublicReservationStatus.error) {
      return _FramedScreen(
        safe: safe,
        step: 1,
        onBack: _goBack,
        backLabel: 'Volver',
        child: PublicBottomAligned(
          child: PublicStateBlock(
            icon: InkSlotIcons.sinConexion,
            title: 'No pudimos cargar la reserva',
            message:
                controller.reservationError ??
                'Intenta nuevamente en unos momentos.',
            onRetry: controller.retryReservation,
          ),
        ),
      );
    }
    if (status != PublicReservationStatus.active) {
      return _FramedScreen(
        safe: safe,
        step: 1,
        onBack: _goBack,
        backLabel: 'Volver',
        child: PublicBottomAligned(child: PublicBlockedMessage(status: status)),
      );
    }

    final availabilityStatus = controller.availabilityStatus;
    final timezone = controller.availability?.timezone ?? reservation.timezone;
    final day = controller.selectedDay;
    if (_step == 1 &&
        availabilityStatus == PublicAvailabilityStatus.loading &&
        _pickedDate != null) {
      return _TimeScreen(
        safe: safe,
        date: _pickedDate!,
        reservation: reservation,
        onBack: _goBack,
        body: const _TimeLoading(),
      );
    }
    if (_step == 1 && day != null) {
      return _TimeScreen(
        safe: safe,
        date: day.date,
        reservation: reservation,
        onBack: _goBack,
        body: _TimeBody(
          slots: day.slots,
          timezone: timezone,
          selectedSlot: controller.selectedSlot,
          onSelected: (slot) {
            controller.selectSlot(slot);
            widget.onReview?.call();
          },
        ),
      );
    }

    final month = _month ?? _initialMonth(reservation);
    final failed =
        availabilityStatus == PublicAvailabilityStatus.error ||
        availabilityStatus == PublicAvailabilityStatus.offline ||
        availabilityStatus == PublicAvailabilityStatus.calendarUnavailable;
    return _FramedScreen(
      safe: safe,
      step: 1,
      onBack: _goBack,
      backLabel: 'Volver',
      scrollable: !failed,
      header: _DayHeading(duration: reservation.durationMinutes),
      child: failed
          ? SingleChildScrollView(
              child: _AvailabilityFailure(
                status: availabilityStatus,
                onRetry: controller.retryAvailability,
              ),
            )
          : _CalendarBody(
              month: month,
              reservation: reservation,
              controller: controller,
              loading:
                  availabilityStatus == PublicAvailabilityStatus.loading ||
                  availabilityStatus == PublicAvailabilityStatus.idle,
              onMonth: _changeMonth,
              onSelectDate: controller.selectDate,
              onShowTimes: _showTimes,
            ),
    );
  }
}

/// Marco con cabecera de pasos y, opcionalmente, titular y contenido
/// desplazable con el pie fijo.
class _FramedScreen extends StatelessWidget {
  const _FramedScreen({
    required this.safe,
    required this.step,
    required this.onBack,
    required this.backLabel,
    required this.child,
    this.header,
    this.scrollable = false,
  });

  final EdgeInsets safe;
  final int step;
  final VoidCallback onBack;
  final String backLabel;
  final Widget child;
  final Widget? header;
  final bool scrollable;

  @override
  Widget build(BuildContext context) => InkSlotScreenIn(
    child: Padding(
      padding: EdgeInsets.fromLTRB(20, safe.top, 20, safe.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PublicStepHeader(step: step, onBack: onBack, backLabel: backLabel),
          if (header != null) ...[const SizedBox(height: 28), header!],
          if (scrollable)
            Expanded(child: child)
          else
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 24),
                child: child,
              ),
            ),
        ],
      ),
    ),
  );
}

class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.duration});

  final int duration;

  @override
  Widget build(BuildContext context) => InkSlotRise(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PublicHeading('Elige un día'),
        const SizedBox(height: 10),
        Text(
          'Solo se activan los días con espacio para tu sesión completa de '
          '${publicDurationLabel(duration)}.',
          style: const TextStyle(
            color: InkSlotColors.secondary,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}

class _CalendarBody extends StatelessWidget {
  const _CalendarBody({
    required this.month,
    required this.reservation,
    required this.controller,
    required this.loading,
    required this.onMonth,
    required this.onSelectDate,
    required this.onShowTimes,
  });

  final DateTime month;
  final PublicReservation reservation;
  final PublicReservationController controller;
  final bool loading;
  final ValueChanged<int> onMonth;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onShowTimes;

  @override
  Widget build(BuildContext context) {
    final availability = controller.availability;
    final selected = controller.selectedDay;
    final lower = _lowerBound(reservation);
    final canPrevious = month.isAfter(DateTime(lower.year, lower.month));
    final canNext = !DateTime(
      month.year,
      month.month + 1,
    ).isAfter(_horizon(reservation));
    final empty =
        controller.availabilityStatus == PublicAvailabilityStatus.empty;
    Widget calendar = PublicCalendar(
      month: month,
      availableDays: availability?.days ?? const <AvailabilityDay>[],
      selectedDate: selected?.date,
      onSelectDate: onSelectDate,
    );
    if (loading) {
      calendar = InkSlotPulse(
        duration: const Duration(milliseconds: 1200),
        minOpacity: .5,
        child: calendar,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkSlotRise.step(
                  1,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 26),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${publicCapitalize(publicMonths[month.month - 1])} '
                          '${month.year}',
                          style: inkSlotSerif(26),
                        ),
                        Row(
                          children: [
                            InkSlotIconButton(
                              icon: InkSlotIcons.volver,
                              iconSize: 16,
                              semanticLabel: 'Mes anterior',
                              onPressed: canPrevious && !loading
                                  ? () => onMonth(-1)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            InkSlotIconButton(
                              icon: InkSlotIcons.avanzar,
                              iconSize: 16,
                              semanticLabel: 'Mes siguiente',
                              onPressed: canNext && !loading
                                  ? () => onMonth(1)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                InkSlotRise.step(
                  2,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: calendar,
                  ),
                ),
                if (empty)
                  InkSlotRise.step(
                    3,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: _NoSlotsCard(
                        onContact: () => contactPublicStudio(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: InkSlotColors.copper,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              TextSpan(
                text: 'CON HORARIOS LIBRES',
                style: inkSlotMono(size: 9, color: InkSlotColors.tertiary),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        InkSlotPrimaryButton(
          label: selected == null
              ? 'Selecciona un día'
              : 'Ver horarios del ${publicWeekdaysShort[selected.date.weekday - 1]} '
                    '${selected.date.day}',
          onPressed: selected == null ? null : onShowTimes,
        ),
      ],
    );
  }
}

class _NoSlotsCard extends StatelessWidget {
  const _NoSlotsCard({required this.onContact});

  final VoidCallback onContact;

  @override
  Widget build(BuildContext context) => InkSlotCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aún no hay horarios disponibles',
          style: TextStyle(
            color: InkSlotColors.bone,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'El estudio no tiene espacios dentro de tu rango por ahora. Tu solicitud sigue activa: escríbele para coordinar.',
          style: TextStyle(
            color: InkSlotColors.secondary,
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        InkSlotPress(
          onTap: onContact,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Escribir al estudio',
                style: TextStyle(
                  color: InkSlotColors.bone,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: InkSlotColors.bone,
                ),
              ),
              SizedBox(width: 6),
              InkSlotIcon(InkSlotIcons.flechaDerecha, size: 14),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AvailabilityFailure extends StatelessWidget {
  const _AvailabilityFailure({required this.status, required this.onRetry});

  final PublicAvailabilityStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (icon, tone, title, message) = switch (status) {
      PublicAvailabilityStatus.calendarUnavailable => (
        InkSlotIcons.calendarioAlerta,
        PublicStateTone.warning,
        'No pudimos verificar la agenda',
        'Para no ofrecerte una hora que quizás ya esté ocupada, esperamos a confirmarla con el estudio.',
      ),
      PublicAvailabilityStatus.offline => (
        InkSlotIcons.sinConexion,
        PublicStateTone.neutral,
        'Sin conexión',
        'Revisa tu conexión e intenta nuevamente.',
      ),
      _ => (
        InkSlotIcons.alerta,
        PublicStateTone.warning,
        'No pudimos cargar los horarios',
        'Intenta nuevamente en unos momentos.',
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 76),
      child: PublicStateBlock(
        icon: icon,
        tone: tone,
        title: title,
        message: message,
        onRetry: onRetry,
      ),
    );
  }
}

class _TimeScreen extends StatelessWidget {
  const _TimeScreen({
    required this.safe,
    required this.date,
    required this.reservation,
    required this.onBack,
    required this.body,
  });

  final EdgeInsets safe;
  final DateTime date;
  final PublicReservation reservation;
  final VoidCallback onBack;
  final Widget body;

  @override
  Widget build(BuildContext context) => InkSlotScreenIn(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: safe.top,
          left: 20,
          right: 20,
          child: PublicStepHeader(
            step: 2,
            onBack: onBack,
            backLabel: 'Volver al calendario',
          ),
        ),
        Positioned(
          top: safe.top + 70,
          left: 24,
          right: 24,
          child: InkSlotRise(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PublicHeading(
                  '${publicCapitalize(publicWeekdaysLong[date.weekday - 1])} '
                  '${date.day} ${publicMonthShort(date.month - 1)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Sesión de ${publicDurationShort(reservation.durationMinutes)}',
                  style: const TextStyle(
                    color: InkSlotColors.secondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          top: safe.top + 178,
          bottom: safe.bottom - InkSlotSpacing.safeAreaBottomReference + 42,
          child: body,
        ),
      ],
    ),
  );
}

class _TimeBody extends StatelessWidget {
  const _TimeBody({
    required this.slots,
    required this.timezone,
    required this.selectedSlot,
    required this.onSelected,
  });

  final List<AvailabilitySlot> slots;
  final String timezone;
  final AvailabilitySlot? selectedSlot;
  final ValueChanged<AvailabilitySlot> onSelected;

  @override
  Widget build(BuildContext context) => PublicTimeWheel(
    slots: slots,
    timezone: timezone,
    selectedSlot: selectedSlot,
    onSelected: onSelected,
  );
}

class _TimeLoading extends StatelessWidget {
  const _TimeLoading();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Expanded(child: PublicTimeWheelSkeleton()),
      const SizedBox(height: 22),
      Text(
        'CONSULTANDO LA AGENDA DEL ESTUDIO…',
        textAlign: TextAlign.center,
        style: inkSlotMono(color: InkSlotColors.tertiary),
      ),
      const SizedBox(height: 22),
    ],
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _lowerBound(PublicReservation? reservation) {
  final today = _dateOnly(DateTime.now());
  final minDate = reservation?.restrictions.minDate;
  return minDate != null && minDate.isAfter(today) ? minDate : today;
}

DateTime _horizon(PublicReservation reservation) =>
    reservation.restrictions.maxDate ??
    _lowerBound(reservation).add(const Duration(days: 61));

DateTime _initialMonth(PublicReservation? reservation) {
  var start = _lowerBound(reservation);
  final maxDate = reservation?.restrictions.maxDate;
  if (maxDate != null && maxDate.isBefore(start)) start = maxDate;
  return DateTime(start.year, start.month);
}
