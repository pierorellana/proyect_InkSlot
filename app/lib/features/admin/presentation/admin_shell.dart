import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_mono_label.dart';
import '../../auth/presentation/admin_session_controller.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    required this.child,
    required this.sessionController,
    super.key,
  });

  final Widget child;
  final AdminSessionController sessionController;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;
        final selectedDestination = _destinationFor(
          GoRouterState.of(context).uri.path,
        );
        return isDesktop
            ? Row(
                children: [
                  _AdminRail(
                    sessionController: sessionController,
                    selectedDestination: selectedDestination,
                  ),
                  Expanded(child: _AdminContent(child: child)),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _AdminContent(child: child)),
                  _AdminBottomNavigation(
                    sessionController: sessionController,
                    selectedDestination: selectedDestination,
                  ),
                ],
              );
      },
    ),
  );
}

class _AdminRail extends StatelessWidget {
  const _AdminRail({
    required this.sessionController,
    required this.selectedDestination,
  });

  final AdminSessionController sessionController;
  final _AdminDestination selectedDestination;

  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(24, 28, 18, 24),
      decoration: const BoxDecoration(
        color: InkSlotColors.ink,
        border: Border(right: BorderSide(color: InkSlotColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              InkSlotLogo(size: 34),
              SizedBox(width: 12),
              Text(
                'INKSLOT',
                style: TextStyle(
                  color: InkSlotColors.bone,
                  fontFamily: 'Geist Mono',
                  fontSize: 13,
                  letterSpacing: 2.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),
          const InkSlotMonoLabel('Espacio de trabajo'),
          const SizedBox(height: 12),
          _AdminNavItem(
            label: 'Inicio',
            icon: Icons.home_outlined,
            selected: selectedDestination == _AdminDestination.dashboard,
            onTap: () => context.go('/admin'),
          ),
          _AdminNavItem(
            label: 'Solicitudes',
            icon: Icons.inbox_outlined,
            selected: selectedDestination == _AdminDestination.requests,
            onTap: () => context.go('/admin/requests'),
          ),
          _AdminNavItem(
            label: 'Citas',
            icon: Icons.event_available_outlined,
            selected: selectedDestination == _AdminDestination.appointments,
            onTap: () => context.go('/admin/appointments'),
          ),
          _AdminNavItem(
            label: 'Incidencias',
            icon: Icons.sync_problem_outlined,
            selected: selectedDestination == _AdminDestination.syncIssues,
            onTap: () => context.go('/admin/sync-issues'),
          ),
          const Spacer(),
          _UserTile(sessionController: sessionController),
          const SizedBox(height: 12),
          _LogoutButton(sessionController: sessionController),
        ],
      ),
    ),
  );
}

class _AdminContent extends StatelessWidget {
  const _AdminContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    left: false,
    right: false,
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class _AdminBottomNavigation extends StatelessWidget {
  const _AdminBottomNavigation({
    required this.sessionController,
    required this.selectedDestination,
  });

  final AdminSessionController sessionController;
  final _AdminDestination selectedDestination;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: InkSlotColors.ink,
        border: Border(top: BorderSide(color: InkSlotColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AdminNavItem(
              label: 'Inicio',
              icon: Icons.home_outlined,
              selected: selectedDestination == _AdminDestination.dashboard,
              compact: true,
              onTap: () => context.go('/admin'),
            ),
          ),
          Expanded(
            child: _AdminNavItem(
              label: 'Solicitudes',
              icon: Icons.inbox_outlined,
              selected: selectedDestination == _AdminDestination.requests,
              compact: true,
              onTap: () => context.go('/admin/requests'),
            ),
          ),
          Expanded(
            child: _AdminNavItem(
              label: 'Citas',
              icon: Icons.event_available_outlined,
              selected: selectedDestination == _AdminDestination.appointments,
              compact: true,
              onTap: () => context.go('/admin/appointments'),
            ),
          ),
          Expanded(
            child: _AdminNavItem(
              label: 'Incidencias',
              icon: Icons.sync_problem_outlined,
              selected: selectedDestination == _AdminDestination.syncIssues,
              compact: true,
              onTap: () => context.go('/admin/sync-issues'),
            ),
          ),
          Expanded(
            child: _LogoutButton(
              sessionController: sessionController,
              compact: true,
            ),
          ),
        ],
      ),
    ),
  );
}

enum _AdminDestination { dashboard, requests, appointments, syncIssues }

_AdminDestination _destinationFor(String path) {
  if (path == '/admin') return _AdminDestination.dashboard;
  if (path.startsWith('/admin/appointments')) {
    return _AdminDestination.appointments;
  }
  if (path.startsWith('/admin/sync-issues')) {
    return _AdminDestination.syncIssues;
  }
  return _AdminDestination.requests;
}

class _AdminNavItem extends StatelessWidget {
  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = compact
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          )
        : Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          );

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 18 : 14),
          child: Container(
            height: compact ? 62 : 48,
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
            decoration: BoxDecoration(
              color: selected ? InkSlotColors.tobacco : Colors.transparent,
              borderRadius: BorderRadius.circular(compact ? 18 : 14),
            ),
            alignment: Alignment.center,
            child: DefaultTextStyle(
              style: TextStyle(
                color: selected
                    ? InkSlotColors.copperLight
                    : InkSlotColors.secondary,
                fontSize: compact ? 11 : 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: selected
                      ? InkSlotColors.copperLight
                      : InkSlotColors.secondary,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.sessionController});

  final AdminSessionController sessionController;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: sessionController,
    builder: (context, child) {
      final user = sessionController.user;
      return Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: InkSlotColors.tobacco,
              shape: BoxShape.circle,
            ),
            child: Text(
              (user?.name.isNotEmpty ?? false)
                  ? user!.name[0].toUpperCase()
                  : 'I',
              style: const TextStyle(
                color: InkSlotColors.copperLight,
                fontFamily: 'Instrument Serif',
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Artista',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: InkSlotColors.cream,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Sesión activa',
                  style: TextStyle(
                    color: InkSlotColors.secondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.sessionController, this.compact = false});

  final AdminSessionController sessionController;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final button = TextButton.icon(
      onPressed: () => sessionController.logout(),
      icon: const Icon(Icons.logout, size: 18),
      label: Text(compact ? 'Salir' : 'Cerrar sesión'),
      style: TextButton.styleFrom(
        foregroundColor: InkSlotColors.secondary,
        minimumSize: Size(compact ? 44 : 48, compact ? 62 : 48),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
      ),
    );

    return Semantics(button: true, label: 'Cerrar sesión', child: button);
  }
}
