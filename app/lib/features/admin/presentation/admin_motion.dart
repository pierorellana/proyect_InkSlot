import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_motion.dart';

/// Entrada de pantalla administrativa por escala, sin opacidad ni desplazamiento.
class AdminScaleIn extends StatefulWidget {
  const AdminScaleIn({
    required this.child,
    super.key,
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final Duration duration;

  @override
  State<AdminScaleIn> createState() => _AdminScaleInState();
}

class _AdminScaleInState extends State<AdminScaleIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _scale = Tween<double>(begin: .965, end: 1)
      .animate(
        CurvedAnimation(parent: _controller, curve: InkSlotMotion.sheetCurve),
      );
  bool _started = false;

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
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// Entrada escalonada de componentes administrativos por escala, sin fade.
class AdminScaleRise extends StatefulWidget {
  const AdminScaleRise({
    required this.child,
    super.key,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 420),
  });

  factory AdminScaleRise.step(int step, {Key? key, required Widget child}) =>
      AdminScaleRise(
        key: key,
        delay: Duration(milliseconds: 55 * step),
        child: child,
      );

  final Widget child;
  final Duration delay;
  final Duration duration;

  @override
  State<AdminScaleRise> createState() => _AdminScaleRiseState();
}

class _AdminScaleRiseState extends State<AdminScaleRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration + widget.delay,
  );
  late final Animation<double> _scale;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final total = (widget.duration + widget.delay).inMilliseconds;
    _scale = Tween<double>(begin: .975, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          total == 0 ? 0 : widget.delay.inMilliseconds / total,
          1,
          curve: InkSlotMotion.sheetCurve,
        ),
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
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}

/// `.tok`: giro de 90° en X con escala, 600 ms. Se repite al cambiar [token].
class AdminTok extends StatefulWidget {
  const AdminTok({required this.child, super.key, this.token});

  final Widget child;
  final Object? token;

  @override
  State<AdminTok> createState() => _AdminTokState();
}

class _AdminTokState extends State<AdminTok>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: InkSlotMotion.sheetCurve,
  );
  bool _started = false;

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
  void didUpdateWidget(AdminTok oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.token != widget.token && !inkSlotReduceMotion(context)) {
      _controller.forward(from: 0);
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
    builder: (context, child) => Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, -1 / 800)
        ..rotateX((1 - _curve.value) * math.pi / 2),
      child: Transform.scale(scale: .94 + .06 * _curve.value, child: child),
    ),
  );
}

/// `.chain`: escala .4 + giro −40°, 1.2 s tras 300 ms.
class AdminChain extends StatefulWidget {
  const AdminChain({required this.child, super.key});

  final Widget child;

  @override
  State<AdminChain> createState() => _AdminChainState();
}

class _AdminChainState extends State<AdminChain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: const Interval(.2, 1, curve: InkSlotMotion.sheetCurve),
  );
  bool _started = false;

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
    animation: _curve,
    child: widget.child,
    builder: (context, child) {
      final t = _curve.value;
      return Transform.rotate(
        angle: -40 * math.pi / 180 * (1 - t),
        child: Transform.scale(scale: .4 + .6 * t, child: child),
      );
    },
  );
}
