import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
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
      final initialLoading =
          controller.status == AdminAppointmentsStatus.loading && !hasItems;

      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 32),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Header(),
                const SizedBox(height: 30),
                _FilterBar(
                  selected: controller.filter,
                  onChanged: controller.setFilter,
                ),
                const SizedBox(height: 20),
                if (initialLoading)
                  const _LoadingList()
                else if (controller.status == AdminAppointmentsStatus.error &&
                    !hasItems)
                  _ErrorState(
                    message:
                        controller.errorMessage ??
                        'No se pudieron cargar las citas.',
                    onRetry: () => controller.load(refresh: true),
                  )
                else if (controller.status == AdminAppointmentsStatus.empty)
                  _EmptyState(filter: controller.filter)
                else ...[
                  if (controller.errorMessage != null) ...[
                    _InlineError(
                      message: controller.errorMessage!,
                      onRetry: () => controller.load(refresh: true),
                    ),
                    const SizedBox(height: 14),
                  ],
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => AdminAppointmentCard(
                      appointment: controller.items[index],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (controller.nextCursor != null)
                    _LoadMoreButton(
                      loading:
                          controller.status == AdminAppointmentsStatus.loading,
                      onPressed:
                          controller.status == AdminAppointmentsStatus.loading
                          ? null
                          : controller.loadMore,
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const InkSlotMonoLabel('Espacio de trabajo'),
      const SizedBox(height: 14),
      Text('Citas', style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 9),
      const Text(
        'Consulta tus citas y el estado de sincronización con Calendar.',
        style: TextStyle(color: InkSlotColors.secondary),
      ),
    ],
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onChanged});

  final AdminAppointmentStatus selected;
  final ValueChanged<AdminAppointmentStatus> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _FilterButton(
        label: 'Confirmadas',
        selected: selected == AdminAppointmentStatus.confirmed,
        onTap: () => onChanged(AdminAppointmentStatus.confirmed),
      ),
      _FilterButton(
        label: 'Completadas',
        selected: selected == AdminAppointmentStatus.completed,
        onTap: () => onChanged(AdminAppointmentStatus.completed),
      ),
      _FilterButton(
        label: 'Canceladas',
        selected: selected == AdminAppointmentStatus.cancelled,
        onTap: () => onChanged(AdminAppointmentStatus.cancelled),
      ),
      _FilterButton(
        label: 'No-show',
        selected: selected == AdminAppointmentStatus.noShow,
        onTap: () => onChanged(AdminAppointmentStatus.noShow),
      ),
    ],
  );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Filtrar por $label',
    child: Material(
      color: selected ? InkSlotColors.tobacco : Colors.transparent,
      borderRadius: BorderRadius.circular(InkSlotRadii.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InkSlotRadii.chip),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: InkSlotSpacing.minimumTapTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? InkSlotColors.copper : InkSlotColors.line,
            ),
            borderRadius: BorderRadius.circular(InkSlotRadii.chip),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? InkSlotColors.copperLight
                  : InkSlotColors.secondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    ),
  );
}

class AdminAppointmentCard extends StatelessWidget {
  const AdminAppointmentCard({required this.appointment, super.key});

  final AdminAppointment appointment;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '${appointment.clientName}, ${_statusLabel(appointment.status)}',
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: InkSlotColors.surface,
        borderRadius: BorderRadius.circular(InkSlotRadii.card),
        border: Border.all(color: InkSlotColors.line),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final client = _ClientSummary(appointment: appointment);
          final timing = _TimingSummary(appointment: appointment);
          final status = _StatusSummary(appointment: appointment);
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                client,
                const SizedBox(height: 18),
                timing,
                const SizedBox(height: 18),
                status,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: client),
              const SizedBox(width: 24),
              Expanded(flex: 4, child: timing),
              const SizedBox(width: 24),
              status,
            ],
          );
        },
      ),
    ),
  );
}

class _ClientSummary extends StatelessWidget {
  const _ClientSummary({required this.appointment});

  final AdminAppointment appointment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const InkSlotMonoLabel('Cliente'),
      const SizedBox(height: 8),
      Text(
        appointment.clientName,
        style: Theme.of(context).textTheme.titleLarge,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );
}

class _TimingSummary extends StatelessWidget {
  const _TimingSummary({required this.appointment});

  final AdminAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('dd/MM/yyyy · HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const InkSlotMonoLabel('Horario'),
        const SizedBox(height: 8),
        Text(format.format(appointment.startAt.toLocal())),
        const SizedBox(height: 5),
        Text(
          '${appointment.durationMinutes} min · termina ${DateFormat('HH:mm').format(appointment.endAt.toLocal())}',
          style: const TextStyle(color: InkSlotColors.secondary),
        ),
      ],
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({required this.appointment});

  final AdminAppointment appointment;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StatusBadge(
        label: _statusLabel(appointment.status),
        color: _statusColor(appointment.status),
      ),
      const SizedBox(height: 8),
      Text(
        'Calendar: ${_syncStatusLabel(appointment.syncStatus)}',
        style: TextStyle(
          color: _syncStatusColor(appointment.syncStatus),
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(
      minHeight: InkSlotSpacing.minimumTapTarget,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(InkSlotRadii.chip),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      3,
      (index) => Padding(
        padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            color: InkSlotColors.surface,
            borderRadius: BorderRadius.circular(InkSlotRadii.card),
            border: Border.all(color: InkSlotColors.line),
          ),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final AdminAppointmentStatus filter;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.event_available_outlined,
          size: 38,
          color: InkSlotColors.copperLight,
        ),
        const SizedBox(height: 16),
        Text(
          'No hay citas ${_emptyFilterLabel(filter)}.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Las citas que coincidan con este filtro aparecerán aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(color: InkSlotColors.secondary),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.error.withValues(alpha: 0.35)),
    ),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: InkSlotColors.error.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(InkSlotRadii.chip),
      border: Border.all(color: InkSlotColors.error.withValues(alpha: 0.28)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: InkSlotColors.errorText),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    ),
  );
}

class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkSlotPrimaryButton(
    label: loading ? 'Cargando…' : 'Cargar más',
    onPressed: onPressed,
    trailing: loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: InkSlotColors.ink,
            ),
          )
        : const Icon(Icons.arrow_downward, size: 18),
  );
}

String _statusLabel(AdminAppointmentStatus status) => switch (status) {
  AdminAppointmentStatus.confirmed => 'Confirmada',
  AdminAppointmentStatus.completed => 'Completada',
  AdminAppointmentStatus.cancelled => 'Cancelada',
  AdminAppointmentStatus.noShow => 'No-show',
};

String _emptyFilterLabel(AdminAppointmentStatus status) => switch (status) {
  AdminAppointmentStatus.confirmed => 'confirmadas',
  AdminAppointmentStatus.completed => 'completadas',
  AdminAppointmentStatus.cancelled => 'canceladas',
  AdminAppointmentStatus.noShow => 'no-show',
};

Color _statusColor(AdminAppointmentStatus status) => switch (status) {
  AdminAppointmentStatus.confirmed => InkSlotColors.copperLight,
  AdminAppointmentStatus.completed => InkSlotColors.successText,
  AdminAppointmentStatus.cancelled => InkSlotColors.errorText,
  AdminAppointmentStatus.noShow => InkSlotColors.warningText,
};

String _syncStatusLabel(AdminAppointmentSyncStatus status) => switch (status) {
  AdminAppointmentSyncStatus.pending => 'pendiente',
  AdminAppointmentSyncStatus.synced => 'sincronizado',
  AdminAppointmentSyncStatus.failed => 'con incidencia',
};

Color _syncStatusColor(AdminAppointmentSyncStatus status) => switch (status) {
  AdminAppointmentSyncStatus.pending => InkSlotColors.warningText,
  AdminAppointmentSyncStatus.synced => InkSlotColors.successText,
  AdminAppointmentSyncStatus.failed => InkSlotColors.errorText,
};
