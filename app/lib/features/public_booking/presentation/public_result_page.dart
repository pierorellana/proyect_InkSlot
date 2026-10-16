import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/public_appointment.dart';
import '../domain/public_confirmation.dart';
import 'public_reservation_controller.dart';
import 'public_studio_link.dart';
import 'widgets/public_chrome.dart';
import 'widgets/public_format.dart';
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
  Widget build(BuildContext context) => PublicScreen(
    builder: (context, safe) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _ResultContent(
        safe: safe,
        controller: widget.controller,
        token: widget.token,
        onReturnToDates: widget.onReturnToDates,
        onReload: widget.controller.retryAppointment,
      ),
    ),
  );
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.safe,
    required this.controller,
    required this.token,
    required this.onReturnToDates,
    required this.onReload,
  });

  final EdgeInsets safe;
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
      return _StateScreen(
        safe: safe,
        child:
            controller.token != token ||
                status == PublicConfirmationStatus.loading ||
                status == PublicConfirmationStatus.idle
            ? const PublicTag(
                'Buscando tu reserva',
                color: InkSlotColors.copper,
                live: true,
              )
            : _failure(status),
      );
    }

    final data = _ResultData.from(
      confirmation: confirmation,
      appointment: appointment,
    );
    final date = publicDateParts(data.startAt, data.timezone);
    final artist = controller.reservation?.artistDisplayName;
    final synced = data.syncStatus == 'synced';
    return Stack(
      fit: StackFit.expand,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: -120,
          height: 520,
          child: IgnorePointer(child: _Halo()),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, safe.top + 16, 24, safe.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SuccessMark(),
                      const SizedBox(height: 30),
                      InkSlotRise.step(
                        2,
                        child: Text(
                          'CITA CONFIRMADA',
                          style: inkSlotMono(color: InkSlotColors.success),
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkSlotRise.step(
                        3,
                        child: Text.rich(
                          TextSpan(
                            text: 'Nos vemos el ${date.weekdayLong},\n',
                            children: [
                              TextSpan(
                                text: artist == null
                                    ? 'hasta pronto.'
                                    : 'con $artist.',
                                style: inkSlotSerif(
                                  46,
                                  italic: true,
                                  color: const Color(0xFFCFC9BF),
                                  height: .98,
                                ),
                              ),
                            ],
                          ),
                          style: inkSlotSerif(46, height: .98),
                        ),
                      ),
                      const SizedBox(height: 26),
                      InkSlotRise.step(4, child: _DetailsCard(data: data)),
                      const SizedBox(height: 14),
                      InkSlotRise.step(5, child: _SyncRow(synced: synced)),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              InkSlotPrimaryButton(
                label: 'Guardar en mi calendario',
                leading: const InkSlotIcon(
                  InkSlotIcons.calendarioAgregar,
                  size: 18,
                  color: InkSlotColors.ink,
                ),
                onPressed: () => showInkSlotToast(
                  context,
                  'Evento listo para tu calendario',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InkSlotGhostButton(
                      label: 'Escribir al estudio',
                      onPressed: () => contactPublicStudio(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkSlotGhostButton(
                      label: 'Ver mi reserva',
                      onPressed: onReload,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _failure(PublicConfirmationStatus status) {
    final blocked = switch (status) {
      PublicConfirmationStatus.alreadyBooked => PublicReservationStatus.booked,
      PublicConfirmationStatus.expired => PublicReservationStatus.expired,
      PublicConfirmationStatus.revoked => PublicReservationStatus.revoked,
      _ => null,
    };
    if (blocked != null) return PublicBlockedMessage(status: blocked);
    final canRetry =
        status == PublicConfirmationStatus.offline ||
        status == PublicConfirmationStatus.calendarUnavailable ||
        status == PublicConfirmationStatus.error;
    final (icon, tone, title, message) = switch (status) {
      PublicConfirmationStatus.conflict => (
        InkSlotIcons.reloj,
        PublicStateTone.error,
        'Ese horario ya no está disponible',
        'Regresa a fechas para elegir otro espacio.',
      ),
      PublicConfirmationStatus.calendarUnavailable => (
        InkSlotIcons.calendarioAlerta,
        PublicStateTone.warning,
        'No pudimos verificar la agenda',
        'No mostraremos datos hasta poder verificar la agenda del estudio.',
      ),
      PublicConfirmationStatus.offline => (
        InkSlotIcons.sinConexion,
        PublicStateTone.neutral,
        'Sin conexión',
        'Revisa tu conexión e intenta nuevamente.',
      ),
      _ => (
        InkSlotIcons.alerta,
        PublicStateTone.warning,
        'No pudimos cargar tu reserva',
        controller.confirmationError ?? 'Intenta nuevamente en unos momentos.',
      ),
    };
    return PublicStateBlock(
      icon: icon,
      tone: tone,
      title: title,
      message: message,
      onRetry: canRetry ? onReload : null,
      secondaryLabel: 'Volver a fechas',
      onSecondary: onReturnToDates,
    );
  }
}

class _StateScreen extends StatelessWidget {
  const _StateScreen({required this.safe, required this.child});

  final EdgeInsets safe;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(24, safe.top, 24, safe.bottom + 6),
    child: PublicBottomAligned(child: child),
  );
}

class _Halo extends StatelessWidget {
  const _Halo();

  @override
  Widget build(BuildContext context) => const OverflowBox(
    minWidth: 520,
    maxWidth: 520,
    child: DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0x29C87939), Color(0x00C87939)],
          stops: [0, .62],
        ),
      ),
      child: SizedBox(width: 520, height: 520),
    ),
  );
}

/// Sello `.seal` con `stamp`, anillo `ringOut` y check que se dibuja.
class _SuccessMark extends StatefulWidget {
  const _SuccessMark();

  @override
  State<_SuccessMark> createState() => _SuccessMarkState();
}

class _SuccessMarkState extends State<_SuccessMark>
    with SingleTickerProviderStateMixin {
  static const _total = 2.3;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2300),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (inkSlotReduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _phase(double seconds, double delay, double duration, Curve curve) =>
      curve.transform(((seconds - delay) / duration).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Reserva confirmada',
    child: SizedBox(
      width: 92,
      height: 92,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final s = _controller.value * _total;
          final stamp = _phase(s, .15, .8, const Cubic(.2, 1.4, .4, 1));
          final ring = _phase(s, .7, 1.6, Curves.easeOut);
          final check = _phase(s, .9, .6, Curves.ease);
          Widget seal = _Seal(check: check);
          final blur = 8 * (1 - stamp.clamp(0.0, 1.0));
          seal = Transform.scale(
            scale: 1.9 + (1 - 1.9) * stamp,
            child: Transform.rotate(
              angle: -14 * math.pi / 180 * (1 - stamp),
              child: seal,
            ),
          );
          if (blur > .05) {
            seal = ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: seal,
            );
          }
          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (ring > 0 && ring < 1)
                Positioned.fill(
                  child: Opacity(
                    opacity: .9 * (1 - ring),
                    child: Transform.scale(
                      scale: 1 + 1.6 * ring,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x80EEE9E0)),
                        ),
                      ),
                    ),
                  ),
                ),
              Opacity(opacity: stamp.clamp(0.0, 1.0), child: seal),
            ],
          );
        },
      ),
    ),
  );
}

class _Seal extends StatelessWidget {
  const _Seal({required this.check});

  final double check;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        width: 92,
        height: 92,
        decoration: const BoxDecoration(
          color: InkSlotColors.bone,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const InkSlotLogo(
          size: 34,
          color: InkSlotColors.ink,
          semanticsLabel: 'Dodogio',
        ),
      ),
      Positioned(
        right: -4,
        bottom: -4,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: InkSlotColors.success,
            shape: BoxShape.circle,
            border: Border.all(color: InkSlotColors.ink, width: 3),
          ),
          alignment: Alignment.center,
          child: CustomPaint(
            size: const Size(16, 16),
            painter: _CheckPainter(check),
          ),
        ),
      ),
    ],
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final scale = size.width / 24;
    final path = Path()
      ..moveTo(5 * scale, 12.5 * scale)
      ..lineTo(9.5 * scale, 17 * scale)
      ..lineTo(19 * scale, 7.5 * scale);
    final partial = Path();
    for (final metric in path.computeMetrics()) {
      partial.addPath(
        metric.extractPath(0, metric.length * progress),
        Offset.zero,
      );
    }
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3 * scale
        ..color = InkSlotColors.ink,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.data});

  final _ResultData data;

  @override
  Widget build(BuildContext context) {
    final date = publicDateParts(data.startAt, data.timezone);
    return Semantics(
      container: true,
      label: 'Resumen de tu reserva confirmada',
      child: InkSlotCard(
        child: Column(
          children: [
            _DetailRow(
              'Fecha',
              '${publicCapitalize(date.weekdayShort)} ${date.day} ${date.monthShort}',
            ),
            const InkSlotSep(indent: 20),
            _DetailRow(
              'Horario',
              '${formatPublicTime(data.startAt, data.timezone)} – '
                  '${formatPublicTime(data.endAt, data.timezone)}',
            ),
            const InkSlotSep(indent: 20),
            _DetailRow(
              'Zona',
              publicZoneDescription(data.timezone).replaceFirst('hora de ', ''),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: InkSlotColors.secondary, fontSize: 15),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: InkSlotColors.bone,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SyncRow extends StatelessWidget {
  const _SyncRow({required this.synced});

  final bool synced;

  @override
  Widget build(BuildContext context) {
    final color = synced ? InkSlotColors.success : InkSlotColors.warning;
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (!synced) dot = InkSlotPulse(child: dot);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 6), child: dot),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              synced
                  ? 'Registrada en la agenda del estudio. Si necesitas cambiarla, escríbele al estudio.'
                  : 'Tu horario ya está reservado. Estamos terminando de registrarlo en la agenda del estudio; no necesitas hacer nada.',
              style: const TextStyle(
                color: InkSlotColors.ash,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultData {
  const _ResultData({
    required this.syncStatus,
    required this.startAt,
    required this.endAt,
    required this.timezone,
  });

  final String syncStatus;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;

  factory _ResultData.from({
    PublicConfirmation? confirmation,
    PublicAppointment? appointment,
  }) => _ResultData(
    syncStatus: confirmation?.syncStatus ?? appointment!.syncStatus,
    startAt: confirmation?.startAt ?? appointment!.startAt,
    endAt: confirmation?.endAt ?? appointment!.endAt,
    timezone: confirmation?.timezone ?? appointment!.timezone,
  );
}
