import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_icon.dart';
import '../../../../core/widgets/inkslot_kit.dart';
import '../../../../core/widgets/inkslot_motion.dart';
import '../../../../core/widgets/inkslot_primary_button.dart';
import '../public_reservation_controller.dart';
import '../public_studio_link.dart';

const publicMaxWidth = 560.0;

/// Marco de pantalla del cliente: fondo tinta, entrada `scrIn`, grano y
/// ancho acotado con las zonas seguras de referencia (58 / 34).
class PublicScreen extends StatelessWidget {
  const PublicScreen({required this.builder, super.key, this.animateIn = true});

  final Widget Function(BuildContext context, EdgeInsets safe) builder;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final safe = EdgeInsets.only(
      top: math.max(padding.top, InkSlotSpacing.safeAreaTopReference),
      bottom: math.max(padding.bottom, InkSlotSpacing.safeAreaBottomReference),
    );
    Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: publicMaxWidth),
        child: builder(context, safe),
      ),
    );
    if (animateIn) content = InkSlotScreenIn(child: content);
    return Scaffold(
      backgroundColor: InkSlotColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          content,
          const Positioned.fill(
            child: RepaintBoundary(child: InkSlotGrain(opacity: .06)),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de pasos: volver `.ib`, tres `.tab` y contador `n/3`.
class PublicStepHeader extends StatelessWidget {
  const PublicStepHeader({
    required this.step,
    required this.onBack,
    required this.backLabel,
    super.key,
  });

  final int step;
  final VoidCallback? onBack;
  final String backLabel;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      InkSlotIconButton(
        icon: InkSlotIcons.volver,
        iconSize: 18,
        onPressed: onBack,
        semanticLabel: backLabel,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(child: _Tab(filled: i <= step)),
            ],
          ],
        ),
      ),
      const SizedBox(width: 14),
      SizedBox(
        width: 44,
        child: Text(
          '$step/3',
          textAlign: TextAlign.right,
          style: inkSlotMono(color: InkSlotColors.tertiary),
        ),
      ),
    ],
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
    height: 6,
    decoration: BoxDecoration(
      color: const Color(0x1FEEE9E0),
      borderRadius: BorderRadius.circular(3),
    ),
    clipBehavior: Clip.antiAlias,
    alignment: Alignment.centerLeft,
    child: AnimatedFractionallySizedBox(
      duration: inkSlotReduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 600),
      curve: InkSlotMotion.standard,
      widthFactor: filled ? 1 : 0,
      heightFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: InkSlotColors.copper,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    ),
  );
}

/// Título serif de pantalla (`h1.serif`, 40 px, interlineado 1).
class PublicHeading extends StatelessWidget {
  const PublicHeading(this.text, {super.key, this.size = 40});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text, style: inkSlotSerif(size));
}

/// Punto + etiqueta mono de estado (`Cita confirmada`, `Enlace vencido`…).
class PublicTag extends StatelessWidget {
  const PublicTag(
    this.label, {
    required this.color,
    super.key,
    this.live = false,
  });

  final String label;
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (live) dot = InkSlotPulse(child: dot);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot,
        const SizedBox(width: 8),
        Flexible(
          child: Text(label.toUpperCase(), style: inkSlotMono(color: color)),
        ),
      ],
    );
  }
}

enum PublicStateTone { warning, error, success, neutral }

Color publicToneColor(PublicStateTone tone) => switch (tone) {
  PublicStateTone.warning => InkSlotColors.warning,
  PublicStateTone.error => InkSlotColors.error,
  PublicStateTone.success => InkSlotColors.success,
  PublicStateTone.neutral => InkSlotColors.bone,
};

/// Bloque de estado del prototipo (icono en círculo de 64, título 22/500,
/// texto 15, acciones). Se usa para agenda no verificable, sin conexión, etc.
class PublicStateBlock extends StatelessWidget {
  const PublicStateBlock({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.tone = PublicStateTone.neutral,
    this.retryLabel = 'Reintentar',
    this.onRetry,
    this.retrying = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final InkSlotIcons icon;
  final String title;
  final String message;
  final PublicStateTone tone;
  final String retryLabel;
  final VoidCallback? onRetry;
  final bool retrying;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => InkSlotRise(
    child: Semantics(
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: InkSlotColors.sheet,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0x1AEEE9E0)),
            ),
            alignment: Alignment.center,
            child: InkSlotIcon(icon, size: 26, color: publicToneColor(tone)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: InkSlotColors.bone,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              color: InkSlotColors.secondary,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          if (onRetry != null || retrying) ...[
            const SizedBox(height: 18),
            InkSlotPrimaryButton(
              label: retrying ? 'Conectando…' : retryLabel,
              loading: retrying,
              onPressed: onRetry ?? () {},
            ),
          ],
          if (secondaryLabel != null) ...[
            const SizedBox(height: 10),
            InkSlotGhostButton(label: secondaryLabel!, onPressed: onSecondary),
          ],
        ],
      ),
    ),
  );
}

/// Enlace de texto del prototipo (`¿Dudas? Escríbele al estudio`).
class PublicTextLink extends StatelessWidget {
  const PublicTextLink(
    this.label, {
    required this.onTap,
    super.key,
    this.color = InkSlotColors.ash,
    this.weight = FontWeight.w400,
  });

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => InkSlotPress(
    onTap: onTap,
    child: SizedBox(
      height: 44,
      child: Center(
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 14, fontWeight: weight),
        ),
      ),
    ),
  );
}

/// Mensaje de enlace no utilizable (vencido / cancelado / ya agendado):
/// etiqueta mono, titular serif 40, texto y botón «Escribir al estudio».
class PublicBlockedMessage extends StatelessWidget {
  const PublicBlockedMessage({required this.status, super.key, this.middle});

  final PublicReservationStatus status;
  final Widget? middle;

  @override
  Widget build(BuildContext context) {
    final (tag, tone, title, body) = switch (status) {
      PublicReservationStatus.expired => (
        'Enlace vencido',
        InkSlotColors.warning,
        'Este enlace ya venció.',
        'Tu anticipo sigue registrado y tu solicitud no se ha perdido. Pide al estudio un enlace nuevo para elegir tu horario.',
      ),
      PublicReservationStatus.revoked => (
        'Solicitud cancelada',
        InkSlotColors.error,
        'Esta solicitud fue cancelada.',
        'El estudio cerró esta solicitud, así que el enlace ya no permite reservar. Si crees que es un error, escríbele directamente.',
      ),
      _ => (
        'Cita confirmada',
        InkSlotColors.success,
        'Ya tienes tu cita.',
        'Este enlace ya se usó para reservar. Para cambiar la fecha, coordina con el estudio.',
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkSlotRise(child: PublicTag(tag, color: tone)),
        const SizedBox(height: 20),
        InkSlotRise.step(
          1,
          child: PublicHeadline(title: title, body: body),
        ),
        if (middle != null) ...[
          const SizedBox(height: 20),
          InkSlotRise.step(2, child: middle!),
        ],
        const SizedBox(height: 20),
        InkSlotRise.step(
          3,
          child: InkSlotGhostButton(
            label: 'Escribir al estudio',
            onPressed: () => contactPublicStudio(context),
          ),
        ),
      ],
    );
  }
}

/// Titular serif 40 con texto de apoyo de 16 px.
class PublicHeadline extends StatelessWidget {
  const PublicHeadline({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: inkSlotSerif(40, height: 1.02)),
      const SizedBox(height: 12),
      Text(
        body,
        style: const TextStyle(
          color: InkSlotColors.secondary,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    ],
  );
}

/// Contenido alineado al borde inferior que se desplaza si no cabe.
class PublicBottomAligned extends StatelessWidget {
  const PublicBottomAligned({
    required this.child,
    super.key,
    this.alignment = Alignment.bottomCenter,
  });

  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      reverse: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Align(alignment: alignment, child: child),
      ),
    ),
  );
}
