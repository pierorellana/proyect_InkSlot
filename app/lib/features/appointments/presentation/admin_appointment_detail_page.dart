import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../../../core/widgets/inkslot_state_block.dart';
import '../domain/admin_appointment.dart';
import 'admin_appointment_detail_controller.dart';

class AdminAppointmentDetailPage extends StatefulWidget {
  const AdminAppointmentDetailPage({
    required this.controller,
    required this.appointmentId,
    super.key,
    this.onChanged,
  });

  final AdminAppointmentDetailController controller;
  final String appointmentId;

  /// Se invoca tras una mutación para refrescar la lista de citas.
  final VoidCallback? onChanged;

  @override
  State<AdminAppointmentDetailPage> createState() =>
      _AdminAppointmentDetailPageState();
}

class _AdminAppointmentDetailPageState
    extends State<AdminAppointmentDetailPage> {
  AdminAppointmentDetailController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.load(widget.appointmentId);
    });
  }

  @override
  void didUpdateWidget(covariant AdminAppointmentDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appointmentId != widget.appointmentId) {
      controller.load(widget.appointmentId);
    }
  }

  void _done(String message) {
    widget.onChanged?.call();
    showInkSlotToast(context, message);
  }

  Future<void> _reschedule() async {
    if (!controller.hasAvailability) await controller.loadAvailability();
    if (!mounted) return;
    controller.clearActionError();
    final moved = await showInkSlotSheet<bool>(
      context: context,
      builder: (_) => _RescheduleSheet(controller: controller),
    );
    if (moved == true && mounted) _done('Cita movida · evento actualizado');
  }

  Future<void> _cancel(AdminAppointmentDetail detail) async {
    final confirmed = await showInkSlotSheet<bool>(
      context: context,
      builder: (_) => _CancelSheet(firstName: _firstName(detail.client.name)),
    );
    if (confirmed != true || !mounted) return;
    if (await controller.cancel() && mounted) {
      _done('Cita cancelada · evento eliminado');
    }
  }

  Future<void> _complete() async {
    if (await controller.complete() && mounted) _done('Cita completada');
  }

  Future<void> _noShow() async {
    if (await controller.noShow() && mounted) {
      _done('Cita marcada como no asistió');
    }
  }

  Future<void> _retry() async {
    if (await controller.retrySync() && mounted) {
      final synced =
          controller.detail?.syncStatus == AdminAppointmentSyncStatus.synced;
      _done(
        synced
            ? 'Evento creado en Google Calendar'
            : 'Reintento enviado a Google Calendar',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final top = media.padding.top < 58 ? 58.0 : media.padding.top;
    return InkSlotScreenIn(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final detail = controller.detail;
          final loaded =
              controller.status == AdminAppointmentDetailStatus.loaded;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  top,
                  20,
                  40 + media.padding.bottom,
                ),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: _content(context, detail, loaded),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AdminAppointmentDetail? detail,
    bool loaded,
  ) {
    final back = InkSlotIconButton(
      icon: InkSlotIcons.volver,
      semanticLabel: 'Volver a citas',
      onPressed: () => context.go('/admin/appointments'),
    );
    if (detail == null) {
      final failed = controller.status == AdminAppointmentDetailStatus.error;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: Alignment.centerLeft, child: back),
          const SizedBox(height: 22),
          if (failed)
            InkSlotStateBlock(
              icon: InkSlotIcons.sinConexion,
              title: 'No pudimos abrir esta cita.',
              body: controller.errorMessage ?? 'No se pudo cargar la cita.',
              actionLabel: 'Reintentar',
              onAction: () => controller.load(widget.appointmentId),
            )
          else
            const InkSlotSkeletonRows(count: 3),
        ],
      );
    }

    final start = detail.startAt.toLocal();
    final end = detail.endAt.toLocal();
    final busy = controller.busyAction;
    final active = detail.isActive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            back,
            InkSlotPill(
              appointmentStatusLabel(detail.status),
              tone: appointmentStatusTone(detail.status),
            ),
          ],
        ),
        InkSlotRise.step(
          0,
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.client.name.toUpperCase(),
                  style: inkSlotMono(color: InkSlotColors.tertiary),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: '${_weekdaysFull[start.weekday - 1]} ${start.day} ',
                    children: [
                      TextSpan(
                        text: _months[start.month - 1],
                        style: inkSlotSerif(
                          50,
                          italic: true,
                          color: InkSlotColors.secondary,
                          height: .95,
                        ),
                      ),
                    ],
                  ),
                  style: inkSlotSerif(50, height: .95),
                ),
                const SizedBox(height: 12),
                Text(
                  '${_hm(start)} — ${_hm(end)}',
                  style: const TextStyle(
                    fontFamily: 'Geist Mono',
                    fontSize: 20,
                    color: InkSlotColors.bone,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (controller.actionError != null) ...[
          const SizedBox(height: 18),
          _InlineError(message: controller.actionError!),
        ],
        InkSlotRise.step(
          1,
          child: Padding(
            padding: const EdgeInsets.only(top: 22),
            child: _SyncCard(
              detail: detail,
              retrying: busy == AdminAppointmentAction.retrySync,
              onRetry: busy == null ? _retry : null,
            ),
          ),
        ),
        InkSlotRise.step(
          2,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InkSlotCard(
              child: Column(
                children: [
                  _InfoRow('Duración', _duration(detail.durationMinutes)),
                  const InkSlotSep(),
                  _InfoRow('Contacto', detail.client.contactLabel),
                ],
              ),
            ),
          ),
        ),
        if (active) ...[
          const Spacer(),
          const SizedBox(height: 22),
          InkSlotPrimaryButton(
            label: 'Reprogramar',
            loading: busy == AdminAppointmentAction.reschedule,
            onPressed: busy == null ? _reschedule : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkSlotGhostButton(
                  label: 'Completada',
                  onPressed: busy == null ? _complete : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkSlotGhostButton(
                  label: 'No asistió',
                  onPressed: busy == null ? _noShow : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkSlotPress(
            onTap: busy == null ? () => _cancel(detail) : null,
            child: const SizedBox(
              height: 44,
              child: Center(
                child: Text(
                  'Cancelar cita',
                  style: TextStyle(
                    color: InkSlotColors.errorText,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SyncCard extends StatelessWidget {
  const _SyncCard({
    required this.detail,
    required this.retrying,
    required this.onRetry,
  });

  final AdminAppointmentDetail detail;
  final bool retrying;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cancelled = detail.status == AdminAppointmentStatus.cancelled;
    final (label, color, desc, live) = switch (detail.syncStatus) {
      AdminAppointmentSyncStatus.synced when cancelled => (
        'Evento eliminado',
        InkSlotColors.tertiary,
        'El evento se quitó del calendario.',
        false,
      ),
      AdminAppointmentSyncStatus.synced => (
        'Sincronizada',
        InkSlotColors.success,
        'El evento está creado y al día en tu calendario.',
        false,
      ),
      AdminAppointmentSyncStatus.pending => (
        'Pendiente',
        InkSlotColors.warning,
        'Creando el evento; la cita ya está reservada.',
        true,
      ),
      AdminAppointmentSyncStatus.failed => (
        'Error · reintentable',
        InkSlotColors.error,
        'El horario sigue bloqueado en InkSlot.',
        true,
      ),
    };
    final dot = Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return InkSlotCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          live ? InkSlotPulse(child: dot) : dot,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Calendar · $label',
                  style: const TextStyle(
                    color: InkSlotColors.bone,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    color: InkSlotColors.ash,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (detail.syncStatus == AdminAppointmentSyncStatus.failed) ...[
            const SizedBox(width: 10),
            InkSlotChip(
              label: retrying ? 'Reintentando…' : 'Reintentar',
              selected: false,
              onTap: retrying ? null : onRetry,
              icon: InkSlotIcons.sincronizar,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: InkSlotColors.secondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: InkSlotColors.bone, fontSize: 15),
            ),
          ),
        ],
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x24E2604C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const InkSlotIcon(
            InkSlotIcons.alerta,
            size: 20,
            color: InkSlotColors.errorText,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: InkSlotColors.errorText,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CancelSheet extends StatelessWidget {
  const _CancelSheet({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '¿Cancelar la cita de $firstName?',
        style: inkSlotSerif(32, height: 1.02),
      ),
      const SizedBox(height: 10),
      const Text(
        'Se libera el horario y se elimina el evento de Google Calendar. '
        'El anticipo queda registrado.',
        style: TextStyle(
          color: InkSlotColors.secondary,
          fontSize: 15,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 22),
      InkSlotDangerButton(
        label: 'Cancelar cita',
        onPressed: () => Navigator.of(context).pop(true),
      ),
      const SizedBox(height: 10),
      InkSlotGhostButton(
        label: 'Mantener cita',
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.controller});

  final AdminAppointmentDetailController controller;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  late final List<DateTime> _days = widget.controller.rescheduleDays();
  int _dayIndex = 0;
  DateTime? _time;

  Future<void> _submit() async {
    final time = _time;
    if (time == null) return;
    final ok = await widget.controller.reschedule(time);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final duration = _duration(controller.detail?.durationMinutes ?? 0);
      final times = _days.isEmpty
          ? const <DateTime>[]
          : controller.rescheduleTimes(_days[_dayIndex]);
      final busy = controller.busyAction == AdminAppointmentAction.reschedule;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Reprogramar', style: inkSlotSerif(32)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _days.isEmpty
                  ? 'Configura tu jornada semanal en Agenda para proponer horarios.'
                  : 'Solo horarios válidos para $duration, revalidados al guardar.',
              style: const TextStyle(color: InkSlotColors.ash, fontSize: 14),
            ),
          ),
          if (_days.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < _days.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    InkSlotChip(
                      label:
                          '${_weekdaysShort[_days[i].weekday - 1]} ${_days[i].day}',
                      selected: i == _dayIndex,
                      onTap: () => setState(() {
                        _dayIndex = i;
                        _time = null;
                      }),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: times.isEmpty
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No quedan horarios este día.',
                        style: TextStyle(
                          color: InkSlotColors.ash,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = (constraints.maxWidth - 16) / 3;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final time in times)
                                SizedBox(
                                  width: width,
                                  child: _TimeChip(
                                    label: _hm(time),
                                    selected: _time == time,
                                    onTap: () => setState(() => _time = time),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
          if (controller.actionError != null) ...[
            const SizedBox(height: 14),
            _InlineError(message: controller.actionError!),
          ],
          const SizedBox(height: 18),
          InkSlotPrimaryButton(
            label: 'Mover cita',
            loading: busy,
            onPressed: _time == null || busy ? null : _submit,
          ),
        ],
      );
    },
  );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? InkSlotColors.ink : InkSlotColors.bone;
    return InkSlotPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? InkSlotColors.bone : Colors.transparent,
          borderRadius: BorderRadius.circular(InkSlotRadii.chip),
          border: Border.all(
            color: selected ? InkSlotColors.bone : const Color(0x24EEE9E0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'Geist Mono', fontSize: 14, color: fg),
        ),
      ),
    );
  }
}

const _weekdaysFull = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _weekdaysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _months = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

String _hm(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

String _duration(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder min';
  if (remainder == 0) return '$hours h';
  return '$hours h $remainder min';
}

String appointmentStatusLabel(AdminAppointmentStatus status) =>
    switch (status) {
      AdminAppointmentStatus.confirmed => 'Confirmada',
      AdminAppointmentStatus.completed => 'Completada',
      AdminAppointmentStatus.cancelled => 'Cancelada',
      AdminAppointmentStatus.noShow => 'No asistió',
    };

InkSlotPillTone appointmentStatusTone(AdminAppointmentStatus status) =>
    switch (status) {
      AdminAppointmentStatus.confirmed => InkSlotPillTone.pending,
      AdminAppointmentStatus.completed => InkSlotPillTone.ok,
      AdminAppointmentStatus.cancelled => InkSlotPillTone.cancelled,
      AdminAppointmentStatus.noShow => InkSlotPillTone.expired,
    };
