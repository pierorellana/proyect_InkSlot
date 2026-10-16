import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
import '../domain/admin_dashboard.dart';
import 'admin_dashboard_controller.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({required this.controller, super.key});

  final AdminDashboardController controller;

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
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final dashboard = controller.dashboard;
      final initialLoading =
          controller.status == AdminDashboardStatus.loading &&
          dashboard == null;

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
                if (initialLoading)
                  const _LoadingState()
                else if (dashboard == null)
                  _ErrorState(
                    message:
                        controller.errorMessage ??
                        'No se pudo cargar el dashboard.',
                    onRetry: () => controller.load(refresh: true),
                  )
                else ...[
                  if (controller.status == AdminDashboardStatus.error &&
                      controller.errorMessage != null) ...[
                    _InlineError(
                      message: controller.errorMessage!,
                      onRetry: () => controller.load(refresh: true),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _KpiGrid(dashboard: dashboard),
                  const SizedBox(height: 34),
                  _UpcomingAppointments(
                    appointments: dashboard.nextAppointments,
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
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      InkSlotMonoLabel('Espacio de trabajo'),
      SizedBox(height: 14),
      Text(
        'Inicio',
        style: TextStyle(
          fontFamily: 'Instrument Serif',
          fontSize: 40,
          color: InkSlotColors.bone,
        ),
      ),
      SizedBox(height: 9),
      Text(
        'Una vista rápida de lo que está pasando en tu estudio.',
        style: TextStyle(color: InkSlotColors.secondary),
      ),
    ],
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.dashboard});

  final AdminDashboard dashboard;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = [
        _KpiCard(
          label: 'Solicitudes pendientes',
          value: dashboard.pendingRequests,
          icon: Icons.inbox_outlined,
          color: InkSlotColors.copperLight,
          route: '/admin/requests',
        ),
        _KpiCard(
          label: 'Próximas citas',
          value: dashboard.upcomingAppointments,
          icon: Icons.event_available_outlined,
          color: InkSlotColors.successText,
          route: '/admin/appointments',
        ),
        _KpiCard(
          label: 'Incidencias abiertas',
          value: dashboard.syncIssues,
          icon: Icons.sync_problem_outlined,
          color: InkSlotColors.warningText,
          route: '/admin/sync-issues',
        ),
      ];
      if (constraints.maxWidth < 640) {
        return Column(
          children: [
            for (var index = 0; index < cards.length; index++) ...[
              cards[index],
              if (index < cards.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < cards.length; index++) ...[
            Expanded(child: cards[index]),
            if (index < cards.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    },
  );
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final String route;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: $value',
    child: Material(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(InkSlotRadii.card),
        child: Container(
          constraints: const BoxConstraints.tightFor(height: 148),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InkSlotRadii.card),
            border: Border.all(color: InkSlotColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 21),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward,
                    color: InkSlotColors.tertiary,
                    size: 17,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '$value',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Instrument Serif',
                  fontSize: 36,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: InkSlotColors.secondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _UpcomingAppointments extends StatelessWidget {
  const _UpcomingAppointments({required this.appointments});

  final List<DashboardAppointment> appointments;

  @override
  Widget build(BuildContext context) {
    final content = appointments.isEmpty
        ? const _EmptyState()
        : Column(
            children: [
              for (var index = 0; index < appointments.length; index++) ...[
                _AppointmentCard(appointment: appointments[index]),
                if (index < appointments.length - 1) const SizedBox(height: 12),
              ],
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Próximas citas',
                style: TextStyle(
                  color: InkSlotColors.bone,
                  fontFamily: 'Instrument Serif',
                  fontSize: 28,
                ),
              ),
            ),
            if (appointments.isNotEmpty)
              TextButton(
                onPressed: () => context.go('/admin/appointments'),
                child: const Text('Ver todas'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        content,
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final DashboardAppointment appointment;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InkSlotMonoLabel('Cliente'),
            const SizedBox(height: 7),
            Text(
              appointment.client.name,
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
        final schedule = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InkSlotMonoLabel('Horario'),
            const SizedBox(height: 7),
            Text(_dateLabel(appointment.startAt)),
            const SizedBox(height: 4),
            Text(
              '${appointment.durationMinutes} min · termina ${DateFormat('HH:mm').format(appointment.endAt.toLocal())}',
              style: const TextStyle(color: InkSlotColors.secondary),
            ),
          ],
        );
        final status = Text(
          _syncLabel(appointment.syncStatus),
          style: const TextStyle(
            color: InkSlotColors.successText,
            fontSize: 12,
          ),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 16),
              schedule,
              const SizedBox(height: 14),
              status,
            ],
          );
        }
        return Row(
          children: [
            Expanded(flex: 3, child: details),
            const SizedBox(width: 24),
            Expanded(flex: 4, child: schedule),
            const SizedBox(width: 24),
            status,
          ],
        );
      },
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: List.generate(
          3,
          (index) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: index == 0 ? 0 : 6),
              child: _LoadingCard(height: 132),
            ),
          ),
        ),
      ),
      const SizedBox(height: 34),
      const _LoadingCard(height: 120),
      const SizedBox(height: 12),
      const _LoadingCard(height: 120),
    ],
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
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
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
    decoration: BoxDecoration(
      color: InkSlotColors.surface,
      borderRadius: BorderRadius.circular(InkSlotRadii.card),
      border: Border.all(color: InkSlotColors.line),
    ),
    child: const Column(
      children: [
        Icon(
          Icons.event_available_outlined,
          size: 38,
          color: InkSlotColors.copperLight,
        ),
        SizedBox(height: 14),
        Text(
          'No tienes próximas citas.',
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
      border: Border.all(color: InkSlotColors.error.withValues(alpha: .35)),
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
      color: InkSlotColors.error.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(InkSlotRadii.chip),
      border: Border.all(color: InkSlotColors.error.withValues(alpha: .28)),
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

String _dateLabel(DateTime value) =>
    DateFormat('dd/MM/yyyy · HH:mm').format(value.toLocal());

String _syncLabel(String status) => switch (status) {
  'synced' => 'Calendar: sincronizado',
  'pending' => 'Calendar: pendiente',
  'failed' => 'Calendar: requiere atención',
  _ => 'Calendar: estado desconocido',
};
