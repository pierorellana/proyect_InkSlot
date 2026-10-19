import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';
import 'inkslot_icon.dart';
import 'inkslot_motion.dart';

/// Texto serif de titulares (`.serif`): Instrument Serif, -0.01em.
TextStyle inkSlotSerif(
  double size, {
  Color color = InkSlotColors.bone,
  bool italic = false,
  double height = 1,
}) => TextStyle(
  fontFamily: 'Instrument Serif',
  fontSize: size,
  height: height,
  color: color,
  fontWeight: FontWeight.w400,
  fontStyle: italic ? FontStyle.italic : FontStyle.normal,
  letterSpacing: size * -.01,
);

/// Texto mono de etiquetas (`.mono`): Geist Mono, 11 px, .12em, mayúsculas.
TextStyle inkSlotMono({
  double size = 11,
  Color color = InkSlotColors.ash,
  FontWeight weight = FontWeight.w400,
  double spacing = .12,
}) => TextStyle(
  fontFamily: 'Geist Mono',
  fontSize: size,
  color: color,
  fontWeight: weight,
  letterSpacing: size * spacing,
  height: 1.1,
);

/// `.btn-g`: 52 px, borde .16, texto hueso.
class InkSlotGhostButton extends StatelessWidget {
  const InkSlotGhostButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final InkSlotIcons? icon;
  final double height;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .4 : 1,
    child: InkSlotPress(
      onTap: onPressed,
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          border: Border.all(color: InkSlotColors.lineStrong),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              InkSlotIcon(icon!, size: 20, color: InkSlotColors.bone),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: InkSlotColors.bone,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// `.btn-d`: destructivo, fondo error .14, texto #F08B78.
class InkSlotDangerButton extends StatelessWidget {
  const InkSlotDangerButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .4 : 1,
    child: InkSlotPress(
      onTap: onPressed,
      child: Container(
        height: 52,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0x24E2604C),
          borderRadius: BorderRadius.circular(26),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: InkSlotColors.errorText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

/// `.ib`: botón de icono circular de 44 px.
class InkSlotIconButton extends StatelessWidget {
  const InkSlotIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    super.key,
    this.color = InkSlotColors.bone,
    this.iconSize = 22,
    this.background = const Color(0x0FEEE9E0),
    this.borderColor = InkSlotColors.line,
  });

  final InkSlotIcons icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final Color color;
  final double iconSize;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onPressed == null ? .25 : 1,
    child: InkSlotPress(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: InkSlotIcon(icon, size: iconSize, color: color),
      ),
    ),
  );
}

/// `.card`: radio 24, superficie #131315, borde .08.
class InkSlotCard extends StatelessWidget {
  const InkSlotCard({
    required this.child,
    super.key,
    this.padding,
    this.color = InkSlotColors.surface,
    this.borderColor = InkSlotColors.line,
    this.radius = InkSlotRadii.card,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
    ),
    child: child,
  );
}

/// Separador `.sep`: 1 px, .07, con margen horizontal de 18.
class InkSlotSep extends StatelessWidget {
  const InkSlotSep({super.key, this.indent = 18});

  final double indent;

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: EdgeInsets.symmetric(horizontal: indent),
    color: const Color(0x12EEE9E0),
  );
}

enum InkSlotPillTone { pending, ok, expired, cancelled }

/// `.pill` (st-pend / st-ok / st-exp / st-can): 24 px, mono 10 px.
class InkSlotPill extends StatelessWidget {
  const InkSlotPill(this.label, {required this.tone, super.key, this.dot});

  final String label;
  final InkSlotPillTone tone;
  final bool? dot;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      InkSlotPillTone.pending => (const Color(0x1AEEE9E0), InkSlotColors.bone),
      InkSlotPillTone.ok => (
        const Color(0x248FBF9A),
        InkSlotColors.successText,
      ),
      InkSlotPillTone.expired => (
        const Color(0x24E6C77A),
        InkSlotColors.warningText,
      ),
      InkSlotPillTone.cancelled => (
        const Color(0x24E2604C),
        InkSlotColors.errorText,
      ),
    };
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot ?? false) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: inkSlotMono(size: 10, color: fg, spacing: .1),
          ),
        ],
      ),
    );
  }
}

/// `.chip`: 40 px, radio 20; `.on` = hueso con texto tinta.
class InkSlotChip extends StatelessWidget {
  const InkSlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
    this.icon,
    this.trailingCount,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final InkSlotIcons? icon;
  final int? trailingCount;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? InkSlotColors.ink : InkSlotColors.bone;
    return InkSlotPress(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? InkSlotColors.bone : Colors.transparent,
          borderRadius: BorderRadius.circular(InkSlotRadii.chip),
          border: Border.all(
            color: selected ? InkSlotColors.bone : const Color(0x24EEE9E0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              InkSlotIcon(icon!, size: 18, color: fg),
              const SizedBox(width: 8),
            ],
            Text(label, style: TextStyle(color: fg, fontSize: 14)),
            if (trailingCount != null) ...[
              const SizedBox(width: 8),
              Text(
                '$trailingCount',
                style: TextStyle(color: fg.withValues(alpha: .6), fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `.seg`: control segmentado (#1A1A1D, radio 22, padding 4, opción activa hueso).
class InkSlotSegmented extends StatelessWidget {
  const InkSlotSegmented({
    required this.labels,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: InkSlotColors.field,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: InkSlotPress(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 40,
                decoration: BoxDecoration(
                  color: i == selected
                      ? InkSlotColors.bone
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: i == selected
                          ? InkSlotColors.ink
                          : InkSlotColors.secondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// `.sw`: interruptor 51×31, cobre al activarse, perilla con resorte.
class InkSlotSwitch extends StatelessWidget {
  const InkSlotSwitch({
    required this.value,
    required this.onChanged,
    super.key,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    label: semanticLabel,
    child: InkSlotPress(
      scale: 1,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: SizedBox(
        width: 51,
        height: 44,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 51,
            height: 31,
            decoration: BoxDecoration(
              color: value ? InkSlotColors.copper : const Color(0x29EEE9E0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 350),
              curve: InkSlotMotion.spring,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 27,
                height: 27,
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: InkSlotColors.bone,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// `.fld`: etiqueta 13 px #A7A29A + campo 52 px, radio 16, #1A1A1D.
class InkSlotField extends StatelessWidget {
  const InkSlotField({
    required this.label,
    required this.controller,
    super.key,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.errorText,
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.maxLines = 1,
    this.prefix,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final int maxLines;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: InkSlotColors.secondary, fontSize: 13),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          scrollPadding: const EdgeInsets.symmetric(vertical: 24),
          obscureText: obscure,
          keyboardType: keyboardType,
          onChanged: onChanged,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofillHints: autofillHints,
          maxLines: maxLines,
          cursorColor: InkSlotColors.copper,
          style: const TextStyle(color: InkSlotColors.bone, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6F6B66), fontSize: 16),
            filled: true,
            fillColor: InkSlotColors.field,
            prefixIcon: prefix,
            isDense: false,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines == 1 ? 0 : 16,
            ),
            constraints: maxLines == 1
                ? const BoxConstraints(minHeight: 52, maxHeight: 52)
                : null,
            enabledBorder: border(
              errorText == null ? InkSlotColors.line : InkSlotColors.error,
            ),
            focusedBorder: border(
              errorText == null ? const Color(0x66EEE9E0) : InkSlotColors.error,
            ),
            border: border(InkSlotColors.line),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: InkSlotColors.errorText,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Encabezado de sección `.sec`: título 20 px + acción secundaria.
class InkSlotSectionHeader extends StatelessWidget {
  const InkSlotSectionHeader({
    required this.title,
    super.key,
    this.count,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.titleSize = 20,
    this.titleWeight = FontWeight.w500,
    this.actionSize = 15,
    this.actionMinHeight = 0,
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;
  final double titleSize;
  final FontWeight titleWeight;
  final double actionSize;
  final double actionMinHeight;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 28, 2, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                if (count != null)
                  TextSpan(
                    text: '  $count',
                    style: const TextStyle(
                      color: InkSlotColors.tertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            style: TextStyle(
              color: InkSlotColors.bone,
              fontSize: titleSize,
              fontWeight: titleWeight,
            ),
          ),
        ),
        ?trailing,
        if (actionLabel != null)
          InkSlotPress(
            onTap: onAction,
            child: Container(
              constraints: BoxConstraints(minHeight: actionMinHeight),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: InkSlotColors.secondary,
                  fontSize: actionSize,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// `.grain`: capa de grano de película al 5–6 % (se omite si hay reduce-motion).
class InkSlotGrain extends StatelessWidget {
  const InkSlotGrain({super.key, this.opacity = .05});

  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Opacity(
      opacity: opacity,
      child: CustomPaint(painter: _GrainPainter(), size: Size.infinite),
    ),
  );
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var seed = 1337;
    double next() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final paint = Paint()..color = const Color(0xFFEEE9E0);
    final count = (size.width * size.height / 90).clamp(0, 4000).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawRect(
        Rect.fromLTWH(next() * size.width, next() * size.height, 1, 1),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}

/// Hoja inferior `.sheet` + `.ovl`: overlay 0.6 con blur 6, hoja de radio 38
/// que sube 550 ms con la curva de hoja.
Future<T?> showInkSlotSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool grabber = true,
  bool dismissible = true,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: dismissible,
  barrierLabel: 'Cerrar',
  barrierColor: Colors.transparent,
  transitionDuration: InkSlotMotion.sheet,
  pageBuilder: (context, _, _) => Align(
    alignment: Alignment.bottomCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: InkSlotColors.sheet,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InkSlotRadii.sheet),
            side: const BorderSide(color: InkSlotColors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (grabber)
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0x33EEE9E0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  Builder(builder: builder),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ),
  transitionBuilder: (context, animation, _, child) {
    final fade = CurvedAnimation(parent: animation, curve: Curves.ease);
    final slide = CurvedAnimation(
      parent: animation,
      curve: InkSlotMotion.sheetCurve,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(
            opacity: fade,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: const ColoredBox(color: Color(0x99000000)),
            ),
          ),
        ),
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1.1),
            end: Offset.zero,
          ).animate(slide),
          child: child,
        ),
      ],
    );
  },
);

/// `.toast`: píldora hueso con texto tinta, resorte, 48 px.
void showInkSlotToast(
  BuildContext context,
  String message, {
  InkSlotIcons? icon,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastHost(
      message: message,
      icon: icon ?? InkSlotIcons.check,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({
    required this.message,
    required this.icon,
    required this.onDone,
  });

  final String message;
  final InkSlotIcons icon;
  final VoidCallback onDone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 2400), () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _controller,
      curve: InkSlotMotion.spring,
      reverseCurve: Curves.easeIn,
    );
    return Positioned(
      left: 0,
      right: 0,
      bottom: 108 + MediaQuery.paddingOf(context).bottom,
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _controller,
            child: AnimatedBuilder(
              animation: curve,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, (1 - curve.value) * 20),
                child: Transform.scale(
                  scale: .9 + .1 * curve.value,
                  child: child,
                ),
              ),
              child: Semantics(
                liveRegion: true,
                label: widget.message,
                child: Material(
                  color: InkSlotColors.bone,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkSlotIcon(
                          widget.icon,
                          size: 18,
                          color: InkSlotColors.ink,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: InkSlotColors.ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
