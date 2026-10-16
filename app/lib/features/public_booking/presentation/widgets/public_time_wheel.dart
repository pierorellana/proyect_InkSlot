import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_icon.dart';
import '../../../../core/widgets/inkslot_kit.dart';
import '../../../../core/widgets/inkslot_motion.dart';
import '../../domain/public_availability.dart';
import 'public_time_zone_formatter.dart';

/// Rueda de horarios curva (`.wheel.w2`): píldora activa `.wpill`, puntos
/// `.wdot`, flechas `.wnav`, contador y ayuda. Se mueve con la rueda del
/// ratón, el gesto vertical, las flechas del teclado y los botones.
class PublicTimeWheel extends StatefulWidget {
  const PublicTimeWheel({
    required this.slots,
    required this.timezone,
    required this.selectedSlot,
    required this.onSelected,
    super.key,
  });

  final List<AvailabilitySlot> slots;
  final String timezone;
  final AvailabilitySlot? selectedSlot;

  /// Se invoca al elegir la píldora enfocada.
  final ValueChanged<AvailabilitySlot> onSelected;

  @override
  State<PublicTimeWheel> createState() => _PublicTimeWheelState();
}

class _PublicTimeWheelState extends State<PublicTimeWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late int _focus = _initialFocus();
  late double _from = _focus.toDouble();
  late double _to = _focus.toDouble();
  DateTime? _lastWheel;
  double _drag = 0;

  int _initialFocus() {
    if (widget.slots.isEmpty) return 0;
    final selected = widget.selectedSlot;
    if (selected != null) {
      final index = widget.slots.indexWhere(
        (slot) => slot.startAt == selected.startAt,
      );
      if (index >= 0) return index;
    }
    return math.min(2, widget.slots.length - 1);
  }

  double get _position {
    final t = InkSlotMotion.standard.transform(_controller.value);
    return _from + (_to - _from) * t;
  }

  @override
  void didUpdateWidget(covariant PublicTimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slots.length != widget.slots.length ||
        (widget.slots.isNotEmpty &&
            oldWidget.slots.isNotEmpty &&
            oldWidget.slots.first.startAt != widget.slots.first.startAt)) {
      _focus = _initialFocus();
      _from = _to = _focus.toDouble();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _focusOn(int index) {
    final target = index.clamp(0, widget.slots.length - 1);
    if (target == _focus) return;
    final reduce = inkSlotReduceMotion(context);
    _from = _position;
    _to = target.toDouble();
    setState(() => _focus = target);
    if (reduce) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  void _step(int delta) => _focusOn(_focus + delta);

  void _choose() => widget.onSelected(widget.slots[_focus]);

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final now = DateTime.now();
    final last = _lastWheel;
    if (last != null && now.difference(last).inMilliseconds < 380) return;
    _lastWheel = now;
    _step(event.scrollDelta.dy > 0 ? 1 : -1);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _step(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _step(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _choose();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) return const SizedBox.shrink();
    final count = widget.slots.length;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: 'Horarios disponibles en ${widget.timezone}',
        child: Column(
          children: [
            Expanded(
              child: Listener(
                onPointerSignal: _onPointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onVerticalDragStart: (_) => _drag = 0,
                  onVerticalDragUpdate: (details) =>
                      _drag += details.primaryDelta ?? 0,
                  onVerticalDragEnd: (_) {
                    if (_drag.abs() > 24) _step(_drag < 0 ? 1 : -1);
                    _drag = 0;
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x00000000),
                              Color(0xFF000000),
                              Color(0xFF000000),
                              Color(0x00000000),
                            ],
                            stops: [0, .12, .88, 1],
                          ).createShader(rect),
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => _WheelItems(
                              slots: widget.slots,
                              timezone: widget.timezone,
                              focus: _focus,
                              position: _position,
                              onPick: _focusOn,
                              onChoose: _choose,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 24,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _NavButton(
                                icon: InkSlotIcons.subir,
                                label: 'Horario anterior',
                                onPressed: _focus <= 0 ? null : () => _step(-1),
                              ),
                              const SizedBox(height: 8),
                              _NavButton(
                                icon: InkSlotIcons.bajar,
                                label: 'Horario siguiente',
                                onPressed: _focus >= count - 1
                                    ? null
                                    : () => _step(1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: InkSlotColors.copper,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_focus + 1} de $count horarios libres'.toUpperCase(),
                  style: inkSlotMono(color: const Color(0xFFE2DCD1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Desliza o toca un horario · toca la píldora para elegir',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA39D94),
                fontSize: 14,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final InkSlotIcons icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => InkSlotIconButton(
    icon: icon,
    iconSize: 16,
    semanticLabel: label,
    onPressed: onPressed,
    background: const Color(0x1AEEE9E0),
    borderColor: const Color(0x33EEE9E0),
  );
}

class _WheelItems extends StatelessWidget {
  const _WheelItems({
    required this.slots,
    required this.timezone,
    required this.focus,
    required this.position,
    required this.onPick,
    required this.onChoose,
  });

  final List<AvailabilitySlot> slots;
  final String timezone;
  final int focus;
  final double position;
  final ValueChanged<int> onPick;
  final VoidCallback onChoose;

  static double _opacity(double ad) {
    const stops = [1.0, .92, .62, .36, 0.0];
    if (ad >= 4) return 0;
    final lower = ad.floor();
    return stops[lower] + (stops[lower + 1] - stops[lower]) * (ad - lower);
  }

  @override
  Widget build(BuildContext context) {
    final visible = <int>[
      for (var i = 0; i < slots.length; i++)
        if ((i - position).abs() < 4) i,
    ]..sort((a, b) => (b - position).abs().compareTo((a - position).abs()));
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerY = constraints.maxHeight / 2;
        return ClipRect(
          child: Stack(
            children: [
              for (final i in visible) _positioned(context, i, centerY),
            ],
          ),
        );
      },
    );
  }

  Widget _positioned(BuildContext context, int i, double centerY) {
    final d = i - position;
    final ad = d.abs();
    final capped = math.min(ad, 4);
    final x = capped * capped * 9 + ad * 8;
    final y = d * 86;
    final scale = ad == 0 ? 1.0 : math.max(.7, 1 - ad * .08);
    final blur = ad <= 1 ? 0.0 : (ad - 1) * .4;
    final slot = slots[i];
    final start = formatPublicTime(slot.startAt, timezone);
    final end = formatPublicTime(slot.endAt, timezone);
    final focused = i == focus;
    Widget child = focused
        ? _Pill(
            key: ValueKey('pill-$i'),
            start: start,
            end: end,
            onTap: onChoose,
          )
        : _Dot(start: start, end: end, onTap: () => onPick(i));
    if (blur > .01) {
      child = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: child,
      );
    }
    return Positioned(
      left: 28 + x,
      top: centerY - 40 + y,
      height: 80,
      child: IgnorePointer(
        ignoring: ad > 3,
        child: Opacity(
          opacity: _opacity(ad),
          child: Transform.scale(
            scale: scale,
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.start, required this.end, required this.onTap});

  final String start;
  final String end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      InkSlotPress(
        onTap: onTap,
        semanticLabel: 'Ver $start a $end',
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: InkSlotColors.elevated,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x38EEE9E0)),
          ),
          alignment: Alignment.center,
          child: Text(
            start,
            style: const TextStyle(
              fontFamily: 'Geist Mono',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: InkSlotColors.bone,
            ),
          ),
        ),
      ),
      const SizedBox(width: 16),
      Text(
        'hasta $end',
        style: const TextStyle(color: Color(0xFFB5AFA5), fontSize: 14),
      ),
    ],
  );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.start,
    required this.end,
    required this.onTap,
    super.key,
  });

  final String start;
  final String end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = inkSlotReduceMotion(context)
        ? Duration.zero
        : const Duration(milliseconds: 550);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: InkSlotMotion.sheetCurve,
      builder: (context, t, child) {
        final width = 64 + (280 - 64) * t;
        return InkSlotPress(
          onTap: onTap,
          semanticLabel: 'Elegir $start a $end',
          child: Container(
            width: width,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2B2722), Color(0xFF1B1916)],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0xCCC87939), spreadRadius: 1),
                BoxShadow(color: Color(0x1AC87939), spreadRadius: 6),
                BoxShadow(
                  color: Color(0x66C87939),
                  blurRadius: 40,
                  spreadRadius: -14,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: 280,
              maxWidth: 280,
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 10, 0),
        child: Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  start,
                  style: inkSlotSerif(38, color: InkSlotColors.cream),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HASTA',
                      style: inkSlotMono(
                        size: 10,
                        color: const Color(0xFFB5AFA5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      end,
                      style: const TextStyle(
                        color: InkSlotColors.cream,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: InkSlotColors.copper,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const InkSlotIcon(
                InkSlotIcons.flechaDerecha,
                size: 20,
                color: InkSlotColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Esqueleto de carga (`.skel`): cinco huecos en rueda con pulso de 1.2 s.
class PublicTimeWheelSkeleton extends StatelessWidget {
  const PublicTimeWheelSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final centerY = constraints.maxHeight / 2;
        Widget item(
          double dx,
          double dy,
          double scale,
          double opacity, {
          double width = 64,
        }) {
          return Positioned(
            left: 28,
            top: centerY - 40,
            height: 80,
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.centerLeft,
                  child: Center(
                    child: InkSlotPulse(
                      duration: const Duration(milliseconds: 1200),
                      child: Container(
                        width: width,
                        height: width == 64 ? 64 : 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181A),
                          borderRadius: BorderRadius.circular(
                            width == 64 ? 32 : 40,
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

        return Stack(
          children: [
            item(30, -168, .8, .4),
            item(8, -84, .9, .7),
            item(0, 0, 1, 1, width: 310),
            item(8, 84, .9, .7),
            item(30, 168, .8, .4),
          ],
        );
      },
    ),
  );
}
