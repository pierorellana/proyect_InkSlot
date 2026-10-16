import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_icon.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_logo.dart';
import '../../../core/widgets/inkslot_motion.dart';
import '../../../core/widgets/inkslot_primary_button.dart';
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
    backgroundColor: InkSlotColors.ink,
    body: LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 860;
        final path = GoRouterState.of(context).uri.path;
        final selected = _destinationFor(path);
        final content = _AdminContent(child: child);
        const grain = Positioned.fill(
          child: RepaintBoundary(child: InkSlotGrain()),
        );
        if (isDesktop) {
          return Row(
            children: [
              _AdminRail(
                sessionController: sessionController,
                selected: selected,
              ),
              Expanded(child: Stack(children: [content, grain])),
            ],
          );
        }
        return Stack(
          children: [
            Positioned.fill(child: content),
            grain,
            if (_showsTabBar(path))
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _AdminTabBar(selected: selected),
              ),
          ],
        );
      },
    ),
  );
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

bool _showsTabBar(String path) {
  final normalized = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  return const {
    '/admin',
    '/admin/requests',
    '/admin/appointments',
    '/admin/agenda',
  }.contains(normalized);
}

/// `.tabbar`: píldora flotante de 68 px con blur y FAB central.
class _AdminTabBar extends StatelessWidget {
  const _AdminTabBar({required this.selected});

  final _AdminDestination selected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset > 24 ? bottomInset : 24,
      ),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xDB161618),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0x17EEE9E0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _TabButton(
                      label: 'Inicio',
                      icon: InkSlotIcons.inicio,
                      selected: selected == _AdminDestination.home,
                      onTap: () => context.go('/admin'),
                    ),
                    _TabButton(
                      label: 'Enlaces',
                      icon: InkSlotIcons.enlace,
                      selected: selected == _AdminDestination.requests,
                      onTap: () => context.go('/admin/requests'),
                    ),
                    InkSlotPress(
                      semanticLabel: 'Nueva solicitud',
                      onTap: () => context.go('/admin/requests/new'),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: InkSlotColors.copper,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x99C87939),
                              blurRadius: 28,
                              spreadRadius: -8,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const InkSlotIcon(
                          InkSlotIcons.mas,
                          color: InkSlotColors.ink,
                        ),
                      ),
                    ),
                    _TabButton(
                      label: 'Citas',
                      icon: InkSlotIcons.calendario,
                      selected: selected == _AdminDestination.appointments,
                      onTap: () => context.go('/admin/appointments'),
                    ),
                    _TabButton(
                      label: 'Agenda',
                      icon: InkSlotIcons.reloj,
                      selected: selected == _AdminDestination.agenda,
                      onTap: () => context.go('/admin/agenda'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.tb`: 52×52, icono 22 y etiqueta mono de 9 px.
class _TabButton extends StatelessWidget {
  const _TabButton({
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
    final color = selected ? InkSlotColors.copperLight : InkSlotColors.tertiary;
    return Semantics(
      selected: selected,
      child: InkSlotPress(
        semanticLabel: label,
        onTap: onTap,
        child: ExcludeSemantics(
          child: SizedBox(
            width: 52,
            height: 52,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: const Duration(milliseconds: 250),
              builder: (context, value, _) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkSlotIcon(icon, size: 22, color: value),
                  const SizedBox(height: 3),
                  Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    style: inkSlotMono(size: 9, color: value!, spacing: .06),
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
          const SizedBox(height: 24),
          InkSlotPrimaryButton(
            label: 'Nueva solicitud',
            leading: const InkSlotIcon(InkSlotIcons.mas, size: 20),
            onPressed: () => context.go('/admin/requests/new'),
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
