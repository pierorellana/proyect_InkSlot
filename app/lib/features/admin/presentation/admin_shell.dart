import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_motion.dart';
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 860;
      final path = GoRouterState.of(context).uri.path;
      final selected = _destinationFor(path);
      final content = _AdminContent(child: child);
      final body = isDesktop
          ? Row(
              children: [
                _AdminRail(
                  sessionController: sessionController,
                  selected: selected,
                ),
                Expanded(child: _AdminSurface(content: content)),
              ],
            )
          : Column(
              children: [
                Builder(
                  builder: (scaffoldContext) => _AdminMobileHeader(
                    onOpenMenu: () => Scaffold.of(scaffoldContext).openDrawer(),
                  ),
                ),
                Expanded(child: _AdminSurface(content: content)),
              ],
            );

      return Scaffold(
        backgroundColor: InkSlotColors.ink,
        drawer: isDesktop
            ? null
            : Drawer(
                backgroundColor: InkSlotColors.deep,
                elevation: 0,
                child: _AdminDrawer(
                  sessionController: sessionController,
                  selected: selected,
                ),
              ),
        body: body,
      );
    },
  );
}

class _AdminSurface extends StatelessWidget {
  const _AdminSurface({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(child: content),
      const Positioned.fill(child: RepaintBoundary(child: InkSlotGrain())),
    ],
  );
}

class _AdminMobileHeader extends StatelessWidget {
  const _AdminMobileHeader({required this.onOpenMenu});

  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: InkSlotColors.deep,
        border: Border(bottom: BorderSide(color: InkSlotColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: InkSlotColors.bone,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const InkSlotLogo(size: 17, color: InkSlotColors.ink),
          ),
          const SizedBox(width: 10),
          Text(
            'DODOGIO',
            style: inkSlotMono(
              size: 11,
              color: InkSlotColors.bone,
              spacing: .28,
            ),
          ),
          const Spacer(),
          InkSlotPress(
            semanticLabel: 'Abrir menú',
            onTap: onOpenMenu,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x0FEEE9E0),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: InkSlotColors.line),
              ),
              alignment: Alignment.center,
              child: const CustomPaint(
                size: Size(20, 20),
                painter: _MenuIconPainter(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MenuIconPainter extends CustomPainter {
  const _MenuIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = InkSlotColors.bone
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final y in [4.0, 10.0, 16.0]) {
      canvas.drawLine(Offset(1, y), Offset(size.width - 1, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MenuIconPainter oldDelegate) => false;
}

/// Centra el contenido en 640 px conservando restricciones ajustadas.
class _AdminContent extends StatelessWidget {
  const _AdminContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final side = constraints.maxWidth > 640
          ? (constraints.maxWidth - 640) / 2
          : 0.0;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: side),
        child: child,
      );
    },
  );
}

enum _AdminDestination { home, requests, appointments, agenda, none }

_AdminDestination _destinationFor(String path) {
  if (path == '/admin') return _AdminDestination.home;
  if (path.startsWith('/admin/requests')) return _AdminDestination.requests;
  if (path.startsWith('/admin/appointments')) {
    return _AdminDestination.appointments;
  }
  if (path.startsWith('/admin/agenda')) return _AdminDestination.agenda;
  return _AdminDestination.none;
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({required this.sessionController, required this.selected});

  final AdminSessionController sessionController;
  final _AdminDestination selected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: InkSlotColors.deep,
        border: Border(right: BorderSide(color: InkSlotColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: InkSlotColors.bone,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const InkSlotLogo(size: 18, color: InkSlotColors.ink),
              ),
              const SizedBox(width: 10),
              Text(
                'DODOGIO',
                style: inkSlotMono(
                  size: 12,
                  color: InkSlotColors.bone,
                  spacing: .32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          _DrawerItem(
            label: 'Inicio',
            icon: InkSlotIcons.inicio,
            selected: selected == _AdminDestination.home,
            onTap: () => _go(context, '/admin'),
          ),
          _DrawerItem(
            label: 'Enlaces',
            icon: InkSlotIcons.enlace,
            selected: selected == _AdminDestination.requests,
            onTap: () => _go(context, '/admin/requests'),
          ),
          _DrawerItem(
            label: 'Citas',
            icon: InkSlotIcons.calendario,
            selected: selected == _AdminDestination.appointments,
            onTap: () => _go(context, '/admin/appointments'),
          ),
          _DrawerItem(
            label: 'Agenda',
            icon: InkSlotIcons.reloj,
            selected: selected == _AdminDestination.agenda,
            onTap: () => _go(context, '/admin/agenda'),
          ),
          const Spacer(),
          _UserTile(sessionController: sessionController),
          const SizedBox(height: 14),
          InkSlotGhostButton(
            label: 'Cerrar sesión',
            height: 44,
            onPressed: () {
              Navigator.of(context).pop();
              sessionController.logout();
            },
          ),
        ],
      ),
    ),
  );

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop();
    context.go(location);
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final InkSlotIcons icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? InkSlotColors.copperLight
        : InkSlotColors.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        child: InkSlotPress(
          semanticLabel: label,
          onTap: onTap,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? InkSlotColors.tobacco : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  InkSlotIcon(icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminRail extends StatelessWidget {
  const _AdminRail({required this.sessionController, required this.selected});

  final AdminSessionController sessionController;
  final _AdminDestination selected;

  @override
  Widget build(BuildContext context) => SafeArea(
    right: false,
    child: Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: const BoxDecoration(
        color: InkSlotColors.deep,
        border: Border(right: BorderSide(color: InkSlotColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: InkSlotColors.bone,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const InkSlotLogo(size: 18, color: InkSlotColors.ink),
              ),
              const SizedBox(width: 10),
              Text(
                'DODOGIO',
                style: inkSlotMono(
                  size: 12,
                  color: InkSlotColors.bone,
                  spacing: .32,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          _RailItem(
            label: 'Inicio',
            icon: InkSlotIcons.inicio,
            selected: selected == _AdminDestination.home,
            onTap: () => context.go('/admin'),
          ),
          _RailItem(
            label: 'Enlaces',
            icon: InkSlotIcons.enlace,
            selected: selected == _AdminDestination.requests,
            onTap: () => context.go('/admin/requests'),
          ),
          _RailItem(
            label: 'Citas',
            icon: InkSlotIcons.calendario,
            selected: selected == _AdminDestination.appointments,
            onTap: () => context.go('/admin/appointments'),
          ),
          _RailItem(
            label: 'Agenda',
            icon: InkSlotIcons.reloj,
            selected: selected == _AdminDestination.agenda,
            onTap: () => context.go('/admin/agenda'),
          ),
          const Spacer(),
          _UserTile(sessionController: sessionController),
          const SizedBox(height: 14),
          InkSlotGhostButton(
            label: 'Cerrar sesión',
            height: 44,
            onPressed: sessionController.logout,
          ),
        ],
      ),
    ),
  );
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final InkSlotIcons icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? InkSlotColors.copperLight
        : InkSlotColors.secondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        selected: selected,
        child: InkSlotPress(
          semanticLabel: label,
          onTap: onTap,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? InkSlotColors.tobacco : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  InkSlotIcon(icon, size: 20, color: color),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
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
      final name = user?.name ?? '';
      return Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0x0FEEE9E0),
              shape: BoxShape.circle,
              border: Border.all(color: InkSlotColors.line),
            ),
            child: Text(
              name.isEmpty ? 'I' : name[0].toUpperCase(),
              style: const TextStyle(
                color: InkSlotColors.bone,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Artista' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: InkSlotColors.bone,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text('SESIÓN ACTIVA', style: inkSlotMono(size: 9)),
              ],
            ),
          ),
        ],
      );
    },
  );
}
