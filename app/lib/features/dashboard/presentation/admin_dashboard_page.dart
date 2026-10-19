import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../admin/presentation/admin_date_format.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../../requests/domain/booking_request.dart';
import '../../requests/domain/booking_request_status.dart';
import '../../requests/presentation/booking_requests_controller.dart';
import '../domain/admin_dashboard.dart';
import 'admin_dashboard_controller.dart';

/// Vigencia de referencia del enlace (`48 h`) para el anillo de "Por agendar".
const _referenceLinkHours = 48;

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    required this.controller,
    super.key,
    this.sessionController,
    this.requestsController,
  });

  final AdminDashboardController controller;
  final AdminSessionController? sessionController;
  final BookingRequestsController? requestsController;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _didLoad = false;

  AdminDashboardController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant AdminDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _didLoad = false;
    _scheduleInitialLoad();
  }

  void _scheduleInitialLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didLoad) return;
      _didLoad = true;
      controller.load();
      widget.requestsController?.load(
        refresh: true,
        status: BookingRequestStatus.pending,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width >= 860;
    final topInset = isDesktop
        ? (media.padding.top < 58 ? 58.0 : media.padding.top)
        : 0.0;
    return InkSlotScreenIn(
      duration: const Duration(milliseconds: 550),
      offset: 14,
      fromScale: 1,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          controller,
          ?widget.sessionController,
          ?widget.requestsController,
        ]),
        builder: (context, _) {
          final dashboard = controller.dashboard;
          final initialLoading =
              controller.status == AdminDashboardStatus.loading &&
              dashboard == null;
          final user = widget.sessionController?.user;
          final pending =
              widget.requestsController?.items
                  .where((item) => item.status == BookingRequestStatus.pending)
                  .toList(growable: false) ??
              const <BookingRequest>[];

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              0,
              topInset,
              0,
              120 + media.padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Greeting(name: user?.name),
                      if (initialLoading)
                        const _LoadingState()
                      else if (dashboard == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: _ErrorState(
                            message:
                                controller.errorMessage ??
                                'No se pudo cargar el dashboard.',
                            onRetry: () => controller.load(refresh: true),
                          ),
                        )
                      else ...[
                        if (controller.status == AdminDashboardStatus.error &&
                            controller.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: _InlineError(
                              message: controller.errorMessage!,
                              onRetry: () => controller.load(refresh: true),
                            ),
                          ),
                        if (dashboard.syncIssues > 0)
                          InkSlotRise(
                            delay: const Duration(milliseconds: 60),
                            duration: const Duration(milliseconds: 650),
                            offset: 16,
                            child: _SyncBanner(dashboard: dashboard),
                          ),
                        InkSlotSectionHeader(
                          title: 'Por agendar',
                          count: dashboard.pendingRequests,
                          titleSize: 18,
                          titleWeight: FontWeight.w600,
                          actionSize: 14,
                          actionMinHeight: 44,
                          actionLabel: 'Ver todas',
                          onAction: () => context.go('/admin/requests'),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dashboard != null) ...[
                  _PendingRow(requests: pending),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkSlotSectionHeader(
                          title: 'Próximas citas',
                          titleSize: 18,
                          titleWeight: FontWeight.w600,
                          actionSize: 14,
                          actionMinHeight: 44,
                          actionLabel: 'Ver todas',
                          onAction: () => context.go('/admin/appointments'),
                        ),
                        _UpcomingCard(appointments: dashboard.nextAppointments),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Buenos días'
        : now.hour < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    final trimmed = name?.trim() ?? '';
    final first = trimmed.isEmpty ? null : trimmed.split(RegExp(r'\s+')).first;
    return InkSlotRise(
      duration: const Duration(milliseconds: 650),
      offset: 16,
      child: Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              longDayLabel(now).toUpperCase(),
              style: inkSlotMono(color: InkSlotColors.tertiary),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: first == null ? '$greeting.' : '$greeting, '),
                  if (first != null)
                    TextSpan(
                      text: '$first.',
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
              style: inkSlotSerif(42),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner de incidencias de sincronización (tono aviso).
class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.dashboard});

  final AdminDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final count = dashboard.syncIssues;
    final affected = dashboard.nextAppointments
        .where((appointment) => appointment.syncStatus != 'synced')
        .firstOrNull;
    final subtitle = affected == null
        ? 'Revisa los eventos pendientes de Google Calendar.'
        : '${affected.client.name} · '
              '${shortDayLabel(affected.startAt.toLocal())}';
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: InkSlotPress(
        semanticLabel:
            '$count ${count == 1 ? 'cita sin sincronizar' : 'citas sin sincronizar'}',
        onTap: () => context.go('/admin/sync-issues'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0x14E6C77A),
            borderRadius: BorderRadius.circular(InkSlotRadii.card),
            border: Border.all(color: const Color(0x38E6C77A)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0x29E6C77A),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const InkSlotIcon(
                  InkSlotIcons.sincronizar,
                  size: 18,
                  color: InkSlotColors.warningText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'cita sin sincronizar' : 'citas sin sincronizar'}',
                      style: const TextStyle(
                        color: InkSlotColors.bone,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFBDB4A3),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const InkSlotIcon(
                InkSlotIcons.avanzar,
                size: 16,
                color: InkSlotColors.ash,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.requests});

  final List<BookingRequest> requests;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final request in requests) ...[
            _PendingCard(request: request),
            const SizedBox(width: 12),
          ],
          const _NewRequestCard(),
        ],
      ),
    ),
  );
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.request});

  final BookingRequest request;

  @override
  Widget build(BuildContext context) {
    final hoursLeft =
        (_referenceLinkHours -
                DateTime.now().difference(request.createdAt).inMinutes / 60)
            .ceil()
            .clamp(0, _referenceLinkHours);
    final channel = request.client.contactChannel;
    return InkSlotPress(
      onTap: () => context.go('/admin/requests/${request.id}'),
      child: SizedBox(
        width: 220,
        child: InkSlotCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _VigencyRing(hoursLeft: hoursLeft),
                  const InkSlotPill('Pendiente', tone: InkSlotPillTone.pending),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                request.client.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: InkSlotColors.bone,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  durationLabel(request.durationMinutes),
                  ?channel?.displayName,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: InkSlotColors.ash, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on ContactChannel {
  String get displayName => switch (this) {
    ContactChannel.whatsapp => 'WhatsApp',
    ContactChannel.instagram => 'Instagram',
    ContactChannel.email => 'Correo',
    ContactChannel.phone => 'Teléfono',
  };
}

/// `.ring`: anillo de vigencia (cobre; aviso por debajo de 12 h).
class _VigencyRing extends StatelessWidget {
  const _VigencyRing({required this.hoursLeft});

  final int hoursLeft;

  @override
  Widget build(BuildContext context) {
    final fraction = hoursLeft / _referenceLinkHours;
    final color = hoursLeft < 12 ? InkSlotColors.warning : InkSlotColors.copper;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: inkSlotReduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 900),
      curve: InkSlotMotion.standard,
      builder: (context, value, _) => Semantics(
        label: 'Vigencia: $hoursLeft h',
        child: ExcludeSemantics(
          child: SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: _RingPainter(fraction: value, color: color),
              child: Center(
                child: Text(
                  '${hoursLeft}h',
                  style: const TextStyle(
                    fontFamily: 'Geist Mono',
                    fontSize: 11,
                    color: InkSlotColors.bone,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 20);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0x1AEEE9E0),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

class _NewRequestCard extends StatelessWidget {
  const _NewRequestCard();

  @override
  Widget build(BuildContext context) => InkSlotPress(
    onTap: () => context.go('/admin/requests/new'),
    child: SizedBox(
      width: 140,
      child: CustomPaint(
        foregroundPainter: const _DashedRRectPainter(),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0x33EEE9E0)),
                ),
                alignment: Alignment.center,
                child: const InkSlotIcon(
                  InkSlotIcons.mas,
                  size: 18,
                  color: InkSlotColors.bone,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nueva solicitud',
                style: TextStyle(color: InkSlotColors.secondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.5),
          const Radius.circular(InkSlotRadii.card),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = InkSlotColors.lineStrong;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) => false;
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.appointments});

  final List<DashboardAppointment> appointments;

  @override
  Widget build(BuildContext context) {
    if (appointments.isEmpty) {
      return const InkSlotCard(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Text(
          'No tienes próximas citas.',
          textAlign: TextAlign.center,
          style: TextStyle(color: InkSlotColors.tertiary, fontSize: 14),
        ),
      );
    }
    return InkSlotCard(
      child: Column(
        children: [
          for (var i = 0; i < appointments.length; i++)
            _AppointmentRow(
              appointment: appointments[i],
              last: i == appointments.length - 1,
            ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.appointment, required this.last});

  final DashboardAppointment appointment;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startAt.toLocal();
    final end = appointment.endAt.toLocal();
    final (color, label, pulse) = switch (appointment.syncStatus) {
      'synced' => (InkSlotColors.success, 'Calendar: sincronizado', false),
      'pending' => (InkSlotColors.warning, 'Calendar: pendiente', true),
      'failed' => (InkSlotColors.error, 'Calendar: requiere atención', true),
      _ => (InkSlotColors.tertiary, 'Calendar: estado desconocido', false),
    };
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return InkSlotPress(
      onTap: () => context.go('/admin/appointments'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: Color(0x0FEEE9E0))),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 56,
              decoration: BoxDecoration(
                color: InkSlotColors.surfaceTwo,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayShort(start),
                    style: inkSlotMono(size: 9, color: InkSlotColors.ash),
                  ),
                  Text(
                    '${start.day}',
                    maxLines: 1,
                    softWrap: false,
                    style: inkSlotSerif(26),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: InkSlotColors.bone,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${clockLabel(start)} – ${clockLabel(end)} · '
                    '${durationLabel(appointment.durationMinutes)}',
                    style: const TextStyle(
                      color: InkSlotColors.ash,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Semantics(
              label: label,
              child: pulse ? InkSlotPulse(minOpacity: .35, child: dot) : dot,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => InkSlotPulse(
    minOpacity: .5,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 28),
        InkSlotCard(child: const SizedBox(height: 86)),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(child: InkSlotCard(child: const SizedBox(height: 144))),
            const SizedBox(width: 12),
            Expanded(child: InkSlotCard(child: const SizedBox(height: 144))),
          ],
        ),
        const SizedBox(height: 40),
        InkSlotCard(child: const SizedBox(height: 170)),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => InkSlotCard(
    padding: const EdgeInsets.all(22),
    borderColor: const Color(0x40E2604C),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message, style: const TextStyle(color: InkSlotColors.errorText)),
        const SizedBox(height: 18),
        InkSlotPrimaryButton(label: 'Reintentar', onPressed: onRetry),
      ],
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => InkSlotCard(
    padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
    color: const Color(0x14E2604C),
    borderColor: const Color(0x40E2604C),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: InkSlotColors.errorText,
              fontSize: 14,
            ),
          ),
        ),
        InkSlotPress(
          onTap: onRetry,
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'Reintentar',
              style: TextStyle(color: InkSlotColors.bone, fontSize: 14),
            ),
          ),
        ),
      ],
    ),
  );
}
