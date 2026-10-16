import 'package:flutter/material.dart';

import '../theme/inkslot_tokens.dart';

bool inkSlotReduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// `scrIn`: entrada de pantalla (opacidad + 16 px + escala .985, 600 ms).
class InkSlotScreenIn extends StatefulWidget {
  const InkSlotScreenIn({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 600),
    this.offset = 16,
    this.fromScale = .985,
  });

  final Widget child;
  final Duration duration;
  final double offset;
  final double fromScale;

  @override
  State<InkSlotScreenIn> createState() => _InkSlotScreenInState();
}

class _InkSlotScreenInState extends State<InkSlotScreenIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: InkSlotMotion.standard,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (inkSlotReduceMotion(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) {
      final t = _curve.value;
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * widget.offset),
          child: Transform.scale(
            scale: widget.fromScale + (1 - widget.fromScale) * t,
            child: child,
          ),
        ),
      );
    },
  );
}

/// `rise` + `.d1…d5`: entrada escalonada (opacidad + 18 px, 700 ms).
class InkSlotRise extends StatefulWidget {
  const InkSlotRise({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 700),
    this.offset = 18,
  });

  /// Retardos `.d1`…`.d5` del prototipo (80 ms por paso).
  factory InkSlotRise.step(int step, {Key? key, required Widget child}) =>
      InkSlotRise(
        key: key,
        delay: Duration(milliseconds: 80 * step),
        child: child,
      );

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offset;

  @override
  State<InkSlotRise> createState() => _InkSlotRiseState();
}

class _InkSlotRiseState extends State<InkSlotRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration + widget.delay,
  );
  late final Animation<double> _t;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = (widget.duration + widget.delay).inMilliseconds;
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        total == 0 ? 0 : widget.delay.inMilliseconds / total,
        1,
        curve: InkSlotMotion.standard,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (inkSlotReduceMotion(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _t.value.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - _t.value) * widget.offset),
        child: child,
      ),
    ),
  );
}

/// `.press`: escala .965 al pulsar (200 ms, curva estándar).
class InkSlotPress extends StatefulWidget {
  const InkSlotPress({
    required this.child,
    required this.onTap,
    super.key,
    this.semanticLabel,
    this.behavior = HitTestBehavior.opaque,
    this.scale = .965,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final HitTestBehavior behavior;
  final double scale;

  @override
  State<InkSlotPress> createState() => _InkSlotPressState();
}

class _InkSlotPressState extends State<InkSlotPress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && widget.onTap != null) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.onTap != null,
    label: widget.semanticLabel,
    child: GestureDetector(
      behavior: widget.behavior,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: InkSlotMotion.micro,
        curve: InkSlotMotion.standard,
        child: widget.child,
      ),
    ),
  );
}

/// `pulse` / `.live`: parpadeo de indicadores en vivo y esqueletos.
class InkSlotPulse extends StatefulWidget {
  const InkSlotPulse({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 1400),
    this.minOpacity = .4,
  });

  final Widget child;
  final Duration duration;
  final double minOpacity;

  @override
  State<InkSlotPulse> createState() => _InkSlotPulseState();
}

class _InkSlotPulseState extends State<InkSlotPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!inkSlotReduceMotion(context)) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      // keyframes: 50% { opacity: minOpacity }
      final v = (_controller.value * 2 - 1).abs();
      return Opacity(
        opacity: widget.minOpacity + (1 - widget.minOpacity) * v,
        child: child,
      );
    },
  );
}

/// `spin`: spinner de 18 px con borde actual y cuarto abierto.
class InkSlotSpinner extends StatefulWidget {
  const InkSlotSpinner({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  State<InkSlotSpinner> createState() => _InkSlotSpinnerState();
}

class _InkSlotSpinnerState extends State<InkSlotSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.white;
    return RotationTransition(
      turns: _controller,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: CustomPaint(painter: _SpinnerPainter(color)),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  _SpinnerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawArc(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      0,
      3.1416 * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) => oldDelegate.color != color;
}
