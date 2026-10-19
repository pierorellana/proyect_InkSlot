import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../../core/widgets/inkslot_state_block.dart';
import '../../admin/presentation/admin_layout.dart';
import '../../admin/presentation/admin_motion.dart';
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

  Future<void> _run(RequestAction action, BookingRequest request) async {
    if (controller.mutationStatus == BookingRequestMutationStatus.submitting) {
      return;
    }
    final confirmed = await RequestActionSheet.confirm(
      context,
      action,
      request,
    );
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
            showInkSlotToast(context, 'Enlace revocado');
            await controller.loadDetail(widget.requestId);
          }
        }
      case RequestAction.close:
        {
          await controller.close(widget.requestId);
          if (mounted && controller.mutationError == null) {
            showInkSlotToast(context, 'Solicitud cerrada');
            await controller.loadDetail(widget.requestId);
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final status = controller.detailStatus;
      if (status == BookingRequestDetailStatus.loading ||
          status == BookingRequestDetailStatus.idle) {
        return _DetailScaffold(
          onBack: () => context.go('/admin/requests'),
          children: const [_DetailLoading()],
        );
      }
      if (status == BookingRequestDetailStatus.error ||
          controller.detail == null) {
        return _DetailScaffold(
          onBack: () => context.go('/admin/requests'),
          children: [
            InkSlotStateBlock(
              icon: InkSlotIcons.sinConexion,
              title: 'No pudimos abrir esta solicitud.',
              body: controller.detailError ?? 'No se pudo cargar el detalle.',
              actionLabel: 'Reintentar',
              onAction: () => controller.loadDetail(widget.requestId),
            ),
          ],
        );
      }
      final detail = controller.detail!;
      final request = detail.request;
      return _DetailContent(
        detail: detail,
        submitting:
            controller.mutationStatus ==
            BookingRequestMutationStatus.submitting,
        mutationError: controller.mutationError,
        onBack: () => context.go('/admin/requests'),
        onAction: (action) => _run(action, request),
      );
    },
  );
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.onBack,
    required this.children,
    this.status,
  });

  final VoidCallback onBack;
  final BookingRequestStatus? status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final top = adminPageTopInset(context);
    return AdminScaleIn(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, top < 58 ? 58 : top, 20, 120),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkSlotIconButton(
                      icon: InkSlotIcons.volver,
                      semanticLabel: 'Volver a solicitudes',
                      onPressed: onBack,
                    ),
                    if (status != null)
                      BookingRequestStatusChip(status: status!),
                  ],
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.detail,
    required this.submitting,
    required this.mutationError,
    required this.onBack,
    required this.onAction,
  });

  final BookingRequestDetail detail;
  final bool submitting;
  final String? mutationError;
  final VoidCallback onBack;
  final ValueChanged<RequestAction> onAction;

  @override
  Widget build(BuildContext context) {
    final request = detail.request;
    final client = request.client;
    final contact =
        client.contactValue ?? client.email ?? client.phone ?? 'No registrado';
    final link = detail.currentLink;
    final status = request.status;
    final canAct =
        status == BookingRequestStatus.pending ||
        status == BookingRequestStatus.expired;
    final linkActive =
        status == BookingRequestStatus.pending &&
        link?.status == BookingLinkStatus.active;
    final linkDead = canAct && !linkActive;
    return _DetailScaffold(
      onBack: onBack,
      status: status,
      children: [
        AdminScaleRise.step(
          0,
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(client.name, style: inkSlotSerif(40)),
                const SizedBox(height: 8),
                Text(
                  '${_channelLabel(client.contactChannel)} · $contact',
                  style: const TextStyle(
                    color: InkSlotColors.ash,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (mutationError != null) ...[
          const SizedBox(height: 18),
          _MutationError(message: mutationError!),
        ],
        if (linkActive)
          AdminScaleRise.step(
            1,
            child: _ActiveLinkCard(
              link: link!,
              submitting: submitting,
              onRenew: () => onAction(RequestAction.renew),
              onRevoke: () => onAction(RequestAction.revoke),
            ),
          ),
        if (linkDead)
          AdminScaleRise.step(
            1,
            child: _DeadLinkCard(
              revoked: link?.status == BookingLinkStatus.revoked,
              submitting: submitting,
              onRenew: () => onAction(RequestAction.renew),
            ),
          ),
        if (status == BookingRequestStatus.booked)
          AdminScaleRise.step(1, child: const _BookedCard()),
        AdminScaleRise.step(
          2,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: InkSlotCard(
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Anticipo',
                    value: request.depositVerified ? 'Validado' : 'Pendiente',
                    trailing: request.depositVerified
                        ? const InkSlotIcon(
                            InkSlotIcons.check,
                            size: 16,
                            color: InkSlotColors.success,
                          )
                        : null,
                    valueColor: request.depositVerified
                        ? null
                        : InkSlotColors.warningText,
                  ),
                  if (request.paymentReference != null) ...[
                    const InkSlotSep(),
                    _InfoRow(
                      label: 'Referencia',
                      value: request.paymentReference!,
                    ),
                  ],
                  const InkSlotSep(),
                  _InfoRow(
                    label: 'Duración',
                    value: _formatDuration(request.durationMinutes),
                  ),
                  const InkSlotSep(),
                  _InfoRow(
                    label: 'Restricciones',
                    value: _formatRestrictions(request),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(2, 28, 2, 12),
          child: Text(
            'Historial',
            style: TextStyle(
              color: InkSlotColors.bone,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _Timeline(entries: detail.audit),
        if (canAct)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TextAction(
                label: 'Cerrar solicitud manualmente',
                color: InkSlotColors.errorText,
                onTap: submitting ? null : () => onAction(RequestAction.close),
              ),
            ),
          ),
      ],
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => InkSlotPress(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading) ...[
            InkSlotSpinner(size: 14, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(label, style: TextStyle(color: color, fontSize: 14)),
          ),
        ],
      ),
    ),
  );
}

class _ActiveLinkCard extends StatelessWidget {
  const _ActiveLinkCard({
    required this.link,
    required this.submitting,
    required this.onRenew,
    required this.onRevoke,
  });

  final CurrentBookingLink link;
  final bool submitting;
  final VoidCallback onRenew;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final left = link.expiresAt.difference(DateTime.now());
    final hours = math.max(0, left.inHours);
    final fraction = (left.inMinutes / (48 * 60)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: InkSlotCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _VigenciaRing(
                  fraction: fraction,
                  label: '${hours}h',
                  color: hours < 12
                      ? InkSlotColors.warning
                      : InkSlotColors.copper,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enlace activo',
                        style: TextStyle(
                          color: InkSlotColors.bone,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vence ${_formatDateTime(link.expiresAt)}',
                        style: const TextStyle(
                          fontFamily: 'Geist Mono',
                          fontSize: 13,
                          color: InkSlotColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              children: [
                _TextAction(
                  label: 'Renovar enlace',
                  color: const Color(0xFFCFC9BF),
                  loading: submitting,
                  onTap: submitting ? null : onRenew,
                ),
                _TextAction(
                  label: 'Revocar',
                  color: InkSlotColors.errorText,
                  onTap: submitting ? null : onRevoke,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VigenciaRing extends StatelessWidget {
  const _VigenciaRing({
    required this.fraction,
    required this.label,
    required this.color,
  });

  final double fraction;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: fraction),
    duration: inkSlotReduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 900),
    curve: InkSlotMotion.standard,
    builder: (context, value, _) => SizedBox(
      width: 64,
      height: 64,
      child: CustomPaint(
        painter: _RingPainter(value, color),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Geist Mono',
              fontSize: 10,
              color: InkSlotColors.bone,
            ),
          ),
        ),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48;
    final center = size.center(Offset.zero);
    final radius = 20 * scale;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, paint..color = const Color(0x1AEEE9E0));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

class _DeadLinkCard extends StatelessWidget {
  const _DeadLinkCard({
    required this.revoked,
    required this.submitting,
    required this.onRenew,
  });

  final bool revoked;
  final bool submitting;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 22),
    child: InkSlotCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            revoked ? 'Enlace revocado' : 'El enlace venció sin reserva',
            style: const TextStyle(
              color: InkSlotColors.bone,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'La solicitud y el anticipo siguen registrados. Genera un enlace nuevo; el anterior no volverá a funcionar.',
            style: TextStyle(
              color: InkSlotColors.secondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          InkSlotPrimaryButton(
            label: 'Generar enlace nuevo',
            loading: submitting,
            onPressed: submitting ? null : onRenew,
          ),
        ],
      ),
    ),
  );
}

class _BookedCard extends StatelessWidget {
  const _BookedCard();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 22),
    child: InkSlotCard(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cita agendada',
                  style: TextStyle(
                    color: InkSlotColors.bone,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'El enlace ya se usó; sus acciones están bloqueadas.',
                  style: TextStyle(
                    color: InkSlotColors.secondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          InkSlotIcon(
            InkSlotIcons.calendarioCheck,
            size: 22,
            color: InkSlotColors.success,
          ),
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 52),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: InkSlotColors.secondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor ?? InkSlotColors.bone,
                fontSize: 15,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    ),
  );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries});

  final List<BookingRequestAuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Text(
          'Aún no hay movimientos registrados.',
          style: TextStyle(color: InkSlotColors.secondary, fontSize: 14),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(
                          color: InkSlotColors.bone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (i < entries.length - 1)
                        Expanded(
                          child: Container(
                            width: 1,
                            color: const Color(0x1FEEE9E0),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 38),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _auditLabel(entries[i].action),
                              style: const TextStyle(
                                color: InkSlotColors.bone,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(entries[i].createdAt),
                              style: inkSlotMono(
                                size: 9,
                                color: InkSlotColors.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
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
        color: const Color(0x24E2604C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const InkSlotIcon(
            InkSlotIcons.alerta,
            color: InkSlotColors.errorText,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: InkSlotColors.errorText,
                fontSize: 14,
              ),
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
  Widget build(BuildContext context) => Semantics(
    label: 'Cargando',
    child: const InkSlotPulse(
      child: Padding(
        padding: EdgeInsets.only(top: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkSlotSkeletonBar(width: 240, height: 40, radius: 10),
            SizedBox(height: 12),
            InkSlotSkeletonBar(width: 160, height: 14),
            SizedBox(height: 22),
            InkSlotSkeletonBar(height: 150, radius: 24),
            SizedBox(height: 14),
            InkSlotSkeletonBar(height: 210, radius: 24),
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

String _formatDateTime(DateTime date) {
  final local = date.toLocal();
  return '${_formatDate(local)} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
