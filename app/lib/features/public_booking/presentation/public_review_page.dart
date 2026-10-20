import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_availability.dart';
import '../domain/public_reservation.dart';
import 'public_reservation_controller.dart';
import 'widgets/public_chrome.dart';
import 'widgets/public_format.dart';
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

  Future<void> _confirm() async {
    final confirmation = await widget.controller.confirmSelected(widget.token);
    if (confirmation != null && mounted) widget.onConfirmed();
  }

  @override
  Widget build(BuildContext context) => PublicScreen(
    builder: (context, safe) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _ReviewContent(
        safe: safe,
        controller: widget.controller,
        token: widget.token,
        onBack: widget.onBack,
        onConfirm: _confirm,
      ),
    ),
  );
}

class _ReviewContent extends StatelessWidget {
  const _ReviewContent({
    required this.safe,
    required this.controller,
    required this.token,
    required this.onBack,
    required this.onConfirm,
  });

  final EdgeInsets safe;
  final PublicReservationController controller;
  final String token;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final reservation = controller.reservation;
    final reservationStatus = controller.reservationStatus;
    final confirmationStatus = controller.confirmationStatus;
    final slot = controller.selectedSlot;

    Widget framed(Widget child) => Padding(
      padding: EdgeInsets.fromLTRB(20, safe.top, 20, safe.bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PublicStepHeader(
            step: 3,
            onBack: onBack,
            backLabel: 'Cambiar horario',
          ),
          Expanded(child: PublicBottomAligned(child: child)),
        ],
      ),
    );

    if (controller.token != token ||
        reservation == null ||
        reservationStatus == PublicReservationStatus.idle ||
        reservationStatus == PublicReservationStatus.loading) {
      return framed(
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: PublicTag(
            'Cargando tu reserva',
            color: InkSlotColors.copper,
            live: true,
          ),
        ),
      );
    }
    if (reservationStatus != PublicReservationStatus.active) {
      return framed(
        PublicBlockedMessage(
          status: reservationStatus == PublicReservationStatus.error
              ? PublicReservationStatus.expired
              : reservationStatus,
        ),
      );
    }
    final blockedByConfirmation = switch (confirmationStatus) {
      PublicConfirmationStatus.alreadyBooked => PublicReservationStatus.booked,
      PublicConfirmationStatus.expired => PublicReservationStatus.expired,
      PublicConfirmationStatus.revoked => PublicReservationStatus.revoked,
      _ => null,
    };
    if (blockedByConfirmation != null) {
      return framed(PublicBlockedMessage(status: blockedByConfirmation));
    }
    if (slot == null) {
      return framed(
        PublicStateBlock(
          icon: InkSlotIcons.calendarioVacio,
          title: 'Elige un horario primero',
          message:
              'Vuelve a fechas para seleccionar el espacio que quieres reservar.',
          secondaryLabel: 'Volver',
          onSecondary: onBack,
        ),
      );
    }

    final loading = confirmationStatus == PublicConfirmationStatus.loading;
    final conflict = confirmationStatus == PublicConfirmationStatus.conflict;
    final inlineError = switch (confirmationStatus) {
      PublicConfirmationStatus.calendarUnavailable => (
        InkSlotIcons.calendarioAlerta,
        PublicStateTone.warning,
        'No pudimos verificar la agenda',
        'Para no confirmarte una hora que quizás ya esté ocupada, esperamos a verificarla con el estudio.',
      ),
      PublicConfirmationStatus.offline => (
        InkSlotIcons.sinConexion,
        PublicStateTone.neutral,
        'Sin conexión',
        'Revisa tu conexión e intenta nuevamente.',
      ),
      PublicConfirmationStatus.error => (
        InkSlotIcons.alerta,
        PublicStateTone.warning,
        'No pudimos confirmar la reserva',
        controller.confirmationError ?? 'Intenta nuevamente en unos momentos.',
      ),
      _ => null,
    };
    final canConfirm =
        confirmationStatus == PublicConfirmationStatus.idle ||
        inlineError != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, safe.top, 20, safe.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PublicStepHeader(
                step: 3,
                onBack: loading ? null : onBack,
                backLabel: 'Cambiar horario',
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 28),
                      const InkSlotRise(
                        child: PublicHeading('Revisa y confirma'),
                      ),
                      const SizedBox(height: 22),
                      _ReviewTicket(reservation: reservation, slot: slot),
                      if (inlineError != null) ...[
                        const SizedBox(height: 22),
                        PublicStateBlock(
                          icon: inlineError.$1,
                          tone: inlineError.$2,
                          title: inlineError.$3,
                          message: inlineError.$4,
                        ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.fromLTRB(4, 18, 4, 0),
                          child: Text(
                            'Al confirmar, este horario queda reservado a tu nombre y se registra en la agenda del estudio.',
                            style: TextStyle(
                              color: InkSlotColors.ash,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Opacity(
                opacity: loading ? .28 : 1,
                child: InkSlotPrimaryButton(
                  label: loading
                      ? 'Reservando tu horario…'
                      : inlineError != null
                      ? 'Reintentar'
                      : 'Confirmar cita',
                  loading: loading,
                  onPressed: canConfirm || loading ? onConfirm : null,
                ),
              ),
            ],
          ),
        ),
        if (conflict)
          _ConflictSheet(
            start: formatPublicTime(slot.startAt, reservation.timezone),
            onResolve: onBack,
          ),
      ],
    );
  }
}

/// Hoja `.sheet` + `.ovl` del 409: «Ese horario se acaba de ocupar».
class _ConflictSheet extends StatelessWidget {
  const _ConflictSheet({required this.start, required this.onResolve});

  final String start;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final reduce = inkSlotReduceMotion(context);
    final duration = reduce ? Duration.zero : InkSlotMotion.sheet;
    return Stack(
      fit: StackFit.expand,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 300),
          builder: (context, t, child) => Opacity(opacity: t, child: child),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const ColoredBox(color: Color(0x99000000)),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: publicMaxWidth),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.1, end: 0),
              duration: duration,
              curve: InkSlotMotion.sheetCurve,
              builder: (context, t, child) => FractionalTranslation(
                translation: Offset(0, t),
                child: child,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  8,
                  0,
                  8,
                  8 + MediaQuery.paddingOf(context).bottom * .5,
                ),
                child: Semantics(
                  container: true,
                  label: 'Horario ocupado',
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 26),
                    decoration: BoxDecoration(
                      color: InkSlotColors.sheet,
                      borderRadius: BorderRadius.circular(InkSlotRadii.sheet),
                      border: Border.all(color: InkSlotColors.line),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0x24C87939),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const InkSlotIcon(
                            InkSlotIcons.reloj,
                            size: 24,
                            color: InkSlotColors.error,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Ese horario se acaba de ocupar',
                          style: inkSlotSerif(32, height: 1.02),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Otra persona confirmó las $start hace un instante. No se hizo ningún cobro ni reserva; elige otra hora.',
                          style: const TextStyle(
                            color: InkSlotColors.secondary,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 22),
                        InkSlotPrimaryButton(
                          label: 'Ver horarios actualizados',
                          onPressed: onResolve,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// `.tk`: ticket 3D con entrada `tkIn`, inclinación que sigue al puntero y
/// brillo `.tk-sheen`.
class _ReviewTicket extends StatefulWidget {
  const _ReviewTicket({required this.reservation, required this.slot});

  final PublicReservation reservation;
  final AvailabilitySlot slot;

  @override
  State<_ReviewTicket> createState() => _ReviewTicketState();
}

class _ReviewTicketState extends State<_ReviewTicket>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  late final Animation<double> _in = CurvedAnimation(
    parent: _entry,
    curve: InkSlotMotion.threeDimension,
  );
  Offset _tilt = Offset.zero;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (inkSlotReduceMotion(context)) {
      _entry.value = 1;
    } else {
      _entry.forward();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _track(PointerEvent event) {
    if (inkSlotReduceMotion(context)) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(event.position);
    final px = (local.dx / box.size.width - .5).clamp(-.5, .5);
    final py = (local.dy / box.size.height - .5).clamp(-.5, .5);
    setState(() => _tilt = Offset(-py * 8, px * 10));
  }

  void _reset() => setState(() => _tilt = Offset.zero);

  @override
  Widget build(BuildContext context) {
    final reservation = widget.reservation;
    final slot = widget.slot;
    final timezone = reservation.timezone;
    final date = publicDateParts(slot.startAt, timezone);
    return Semantics(
      container: true,
      label: 'Ticket de revisión para ${reservation.artistDisplayName}',
      child: Listener(
        onPointerHover: _track,
        onPointerMove: _track,
        onPointerUp: (_) => _reset(),
        onPointerCancel: (_) => _reset(),
        child: MouseRegion(
          onExit: (_) => _reset(),
          child: AnimatedBuilder(
            animation: _in,
            builder: (context, child) {
              final t = _in.value;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: TweenAnimationBuilder<Offset>(
                  tween: Tween(begin: _tilt, end: _tilt),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  builder: (context, tilt, _) => Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, -1 / 1100)
                      ..rotateX(tilt.dx * math.pi / 180)
                      ..rotateY(tilt.dy * math.pi / 180)
                      ..rotateX(38 * (1 - t) * math.pi / 180)
                      ..translateByDouble(0, 40 * (1 - t), 0, 1),
                    child: _TicketFace(sheen: 50 + tilt.dy * 6, child: child!),
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DODOGIO',
                            style: inkSlotMono(
                              size: 10,
                              color: InkSlotColors.ash,
                              spacing: .3,
                            ),
                          ),
                          const InkSlotLogo(
                            size: 18,
                            semanticsLabel: 'Dodogio',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '${publicCapitalize(date.weekdayShort)} ${date.day}',
                        style: inkSlotSerif(52, height: .95),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.monthLong} ${date.year}',
                        style: inkSlotSerif(
                          24,
                          italic: true,
                          color: InkSlotColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _TicketTime(formatPublicTime(slot.startAt, timezone)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0x40EEE9E0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _TicketTime(formatPublicTime(slot.endAt, timezone)),
                        ],
                      ),
                    ],
                  ),
                ),
                const _Perforation(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _TicketField(
                              'Duración',
                              publicDurationLabel(reservation.durationMinutes),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _TicketField(
                              'Artista',
                              reservation.artistDisplayName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketFace extends StatelessWidget {
  const _TicketFace({required this.sheen, required this.child});

  final double sheen;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF151517),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0x17EEE9E0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Stack(
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _SheenPainter(sheen)),
          ),
        ),
      ],
    ),
  );
}

/// `linear-gradient(115deg, transparent 30%, bone .07 48%, transparent 62%)`
/// con `background-size: 220% 100%` desplazado según `background-position`.
class _SheenPainter extends CustomPainter {
  _SheenPainter(this.position);

  final double position;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * 2.2;
    final dx = (size.width - width) * position / 100;
    final box = Rect.fromLTWH(dx, 0, width, size.height);
    const angle = 115 * math.pi / 180;
    final direction = Offset(math.sin(angle), -math.cos(angle));
    final length =
        (box.width * math.sin(angle)).abs() +
        (box.height * math.cos(angle)).abs();
    final center = box.center;
    final shader = ui.Gradient.linear(
      center - direction * (length / 2),
      center + direction * (length / 2),
      const [Color(0x00EEE9E0), Color(0x12EEE9E0), Color(0x00EEE9E0)],
      const [.30, .48, .62],
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(box, Paint()..shader = shader);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.position != position;
}

class _TicketTime extends StatelessWidget {
  const _TicketTime(this.value);

  final String value;

  @override
  Widget build(BuildContext context) => Text(
    value,
    style: const TextStyle(
      fontFamily: 'Geist Mono',
      fontSize: 22,
      color: InkSlotColors.bone,
    ),
  );
}

class _TicketField extends StatelessWidget {
  const _TicketField(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: inkSlotMono(size: 9, color: InkSlotColors.tertiary),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(color: InkSlotColors.bone, fontSize: 15),
      ),
    ],
  );
}

/// `.perf`: línea punteada con muescas circulares en ambos bordes.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 1,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 22,
          right: 22,
          top: 0,
          height: 1,
          child: CustomPaint(painter: _DashPainter()),
        ),
        for (final side in [true, false])
          Positioned(
            left: side ? -12 : null,
            right: side ? null : -12,
            top: -12,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: InkSlotColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}

class _DashPainter extends CustomPainter {
  const _DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x2EEEE9E0)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 7) {
      canvas.drawLine(
        Offset(x, .5),
        Offset(math.min(x + 4, size.width), .5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}
