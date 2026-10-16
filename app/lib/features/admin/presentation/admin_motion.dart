import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_motion.dart';

/// `.tok`: giro de 90° en X con fundido, 600 ms. Se repite al cambiar [token].
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
    builder: (context, child) => Opacity(
      opacity: _curve.value.clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, -1 / 800)
          ..rotateX((1 - _curve.value) * math.pi / 2),
        child: child,
      ),
    ),
  );
}

/// `.up-in`: entrada desde abajo, 600 ms.
class AdminUpIn extends StatefulWidget {
  const AdminUpIn({required this.child, super.key});

  final Widget child;

  @override
  State<AdminUpIn> createState() => _AdminUpInState();
}

class _AdminUpInState extends State<AdminUpIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<Offset> _offset =
      Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
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
  Widget build(BuildContext context) => SlideTransition(
    position: _offset,
    child: ColoredBox(color: InkSlotColors.ink, child: widget.child),
  );
}

/// `.chain`: escala .4 + giro −40° con fundido, 1.2 s tras 300 ms.
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
      return Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -40 * math.pi / 180 * (1 - t),
          child: Transform.scale(scale: .4 + .6 * t, child: child),
        ),
      );
    },
  );
}
