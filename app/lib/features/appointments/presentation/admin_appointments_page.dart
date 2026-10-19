import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_state_block.dart';
import '../../admin/presentation/admin_layout.dart';
import '../../admin/presentation/admin_motion.dart';
import '../domain/admin_appointment.dart';
import 'admin_appointments_controller.dart';

class AdminAppointmentsPage extends StatefulWidget {
  const AdminAppointmentsPage({required this.controller, super.key});

  final AdminAppointmentsController controller;

  @override
  State<AdminAppointmentsPage> createState() => _AdminAppointmentsPageState();
}

class _AdminAppointmentsPageState extends State<AdminAppointmentsPage> {
  bool _didLoad = false;

  AdminAppointmentsController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant AdminAppointmentsPage oldWidget) {
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
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final hasItems = controller.items.isNotEmpty;
      final loading = controller.status == AdminAppointmentsStatus.loading;
      final initialLoading = loading && !hasItems;
      final items = controller.items;

      final top = adminPageTopInset(context);
      return AdminScaleIn(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, top, 20, 120),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminScaleRise.step(
                    0,
                    child: Text('Citas', style: inkSlotSerif(42)),
                  ),
                  const SizedBox(height: 18),
                  AdminScaleRise.step(
                    1,
                    child: _FilterBar(
                      selected: controller.filter,
                      onChanged: controller.setFilter,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (initialLoading)
                    const InkSlotSkeletonRows(count: 4, avatar: 52)
                  else if (controller.status == AdminAppointmentsStatus.error &&
                      !hasItems)
                    InkSlotStateBlock(
                      icon: InkSlotIcons.sinConexion,
                      title: 'No pudimos cargar tus citas.',
                      body:
                          controller.errorMessage ??
                          'No se pudieron cargar las citas.',
                      actionLabel: 'Reintentar',
                      onAction: () => controller.load(refresh: true),
                    )
                  else if (controller.status == AdminAppointmentsStatus.empty)
                    InkSlotStateBlock(
                      icon: InkSlotIcons.calendarioVacio,
                      title:
                          'No hay citas ${_emptyFilterLabel(controller.filter)}.',
                      body:
                          'Las citas que coincidan con este filtro aparecerán aquí.',
                    )
                  else ...[
                    if (controller.errorMessage != null) ...[
                      _InlineError(
                        message: controller.errorMessage!,
                        onRetry: () => controller.load(refresh: true),
                      ),
                      const SizedBox(height: 14),
                    ],
                    AdminScaleRise.step(
                      2,
                      child: InkSlotCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < items.length; i++) ...[
                              if (i > 0) const InkSlotSep(indent: 0),
                              AdminAppointmentCard(
                                appointment: items[i],
                                onTap: () => context.go(
                                  '/admin/appointments/${Uri.encodeComponent(items[i].id)}',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (controller.nextCursor != null) ...[
                      const SizedBox(height: 16),
                      InkSlotGhostButton(
                        label: loading ? 'Cargando…' : 'Cargar más',
                        onPressed: loading ? null : controller.loadMore,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final AdminAppointmentStatus selected;
  final ValueChanged<AdminAppointmentStatus> onChanged;

  static const _labels = {
    AdminAppointmentStatus.confirmed: 'Confirmadas',
    AdminAppointmentStatus.completed: 'Completadas',
    AdminAppointmentStatus.cancelled: 'Canceladas',
    AdminAppointmentStatus.noShow: 'No asistió',
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        for (final entry in _labels.entries) ...[
          if (entry.key != AdminAppointmentStatus.confirmed)
            const SizedBox(width: 12),
          Semantics(
            selected: entry.key == selected,
            label: 'Filtrar por ${entry.value}',
            excludeSemantics: true,
            button: true,
            child: InkSlotChip(
              label: entry.value,
              selected: entry.key == selected,
              onTap: () => onChanged(entry.key),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Fila de cita: fecha serif, horario y estado con sincronización.
class AdminAppointmentCard extends StatelessWidget {
  const AdminAppointmentCard({
    required this.appointment,
    super.key,
    this.onTap,
  });

  final AdminAppointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final start = appointment.startAt.toLocal();
    final end = appointment.endAt.toLocal();
    final (syncLabel, syncColor) = switch (appointment.syncStatus) {
      AdminAppointmentSyncStatus.pending => (
        'Pendiente',
        InkSlotColors.warning,
      ),
      AdminAppointmentSyncStatus.synced => (
        'Sincronizada',
        InkSlotColors.success,
      ),
      AdminAppointmentSyncStatus.failed => (
        'Con incidencia',
        InkSlotColors.error,
      ),
    };
    final dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: syncColor, shape: BoxShape.circle),
    );
    return InkSlotPress(
      onTap: onTap,
      scale: .985,
      semanticLabel:
          '${appointment.clientName}, ${_statusLabel(appointment.status)}, '
          'Calendar: $syncLabel',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 56,
                decoration: BoxDecoration(
                  color: InkSlotColors.surfaceTwo,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _weekdays[start.weekday - 1].toUpperCase(),
                        style: inkSlotMono(size: 9, color: InkSlotColors.ash),
                      ),
                      const SizedBox(height: 2),
                      Text('${start.day}', style: inkSlotSerif(26)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: InkSlotColors.bone,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_hm(start)} – ${_hm(end)} · '
                      '${_duration(appointment.durationMinutes)}',
                      style: const TextStyle(
                        color: InkSlotColors.ash,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkSlotPill(
                    _statusLabel(appointment.status),
                    tone: _statusTone(appointment.status),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (appointment.syncStatus ==
                          AdminAppointmentSyncStatus.pending)
                        InkSlotPulse(child: dot)
                      else
                        dot,
                      const SizedBox(width: 5),
                      Text(
                        syncLabel,
                        style: const TextStyle(
                          color: InkSlotColors.ash,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
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
          InkSlotIconButton(
            icon: InkSlotIcons.sincronizar,
            semanticLabel: 'Reintentar',
            onPressed: onRetry,
            color: InkSlotColors.errorText,
          ),
        ],
      ),
    ),
  );
}

const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

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

String _statusLabel(AdminAppointmentStatus status) => switch (status) {
  AdminAppointmentStatus.confirmed => 'Confirmada',
  AdminAppointmentStatus.completed => 'Completada',
  AdminAppointmentStatus.cancelled => 'Cancelada',
  AdminAppointmentStatus.noShow => 'No asistió',
};

InkSlotPillTone _statusTone(AdminAppointmentStatus status) => switch (status) {
  AdminAppointmentStatus.confirmed => InkSlotPillTone.pending,
  AdminAppointmentStatus.completed => InkSlotPillTone.ok,
  AdminAppointmentStatus.cancelled => InkSlotPillTone.cancelled,
  AdminAppointmentStatus.noShow => InkSlotPillTone.expired,
};

String _emptyFilterLabel(AdminAppointmentStatus status) => switch (status) {
  AdminAppointmentStatus.confirmed => 'confirmadas',
  AdminAppointmentStatus.completed => 'completadas',
  AdminAppointmentStatus.cancelled => 'canceladas',
  AdminAppointmentStatus.noShow => 'sin asistencia',
};
