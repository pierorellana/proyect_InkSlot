import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_motion.dart';

/// Escenario `.stage` + `.coin`: la D en capas con `coinIn` y `sway`.
class DCoin extends StatefulWidget {
  const DCoin({super.key});

  static const width = 112.0;
  static const height = 146.0;

  @override
  State<DCoin> createState() => _DCoinState();
}

class _DCoinState extends State<DCoin> with TickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  late final CurvedAnimation _inCurve = CurvedAnimation(
    parent: _in,
    curve: InkSlotMotion.threeDimension,
  );
  late final CurvedAnimation _swayCurve = CurvedAnimation(
    parent: _sway,
    curve: Curves.easeInOut,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (inkSlotReduceMotion(context)) {
      _in.value = 1;
      return;
    }
    _in.forward().whenComplete(() {
      if (mounted) _sway.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _sway.dispose();
    super.dispose();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: 'Logotipo D',
    child: SizedBox(
      width: DCoin.width,
      height: DCoin.height,
      child: AnimatedBuilder(
        animation: Listenable.merge([_inCurve, _swayCurve]),
        builder: (context, _) {
          final entering = !_in.isCompleted;
          final t = _inCurve.value;
          final double angleY;
          final double angleX;
          final double scale;
          if (entering) {
            angleY = _lerp(-math.pi / 2, -18 * math.pi / 180, t);
            angleX = 0;
            scale = _lerp(.7, 1, t);
          } else if (_sway.value == 0 && !_sway.isAnimating) {
            angleY = -18 * math.pi / 180;
            angleX = 0;
            scale = 1;
          } else {
            final s = _swayCurve.value;
            angleY = _lerp(-18, 16, s) * math.pi / 180;
            angleX = _lerp(4, -4, s) * math.pi / 180;
            scale = 1;
          }
          Widget layer(double z, Color color, {bool drop = false}) => Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, -1 / 700)
              ..rotateY(angleY)
              ..rotateX(angleX)
              ..scaleByDouble(scale, scale, scale, 1)
              ..translateByDouble(0, 0, z, 1),
            child: CustomPaint(
              size: const Size(DCoin.width, DCoin.height),
              painter: _DPainter(color, drop: drop),
            ),
          );
          return Opacity(
            opacity: entering ? t.clamp(0.0, 1.0) : 1,
            child: Stack(
              children: [
                layer(-9, const Color(0xFF13110F)),
                layer(-6, const Color(0xFF1E1B18)),
                layer(-3, const Color(0xFF2D2823)),
                layer(0, InkSlotColors.bone, drop: true),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _DPainter extends CustomPainter {
  const _DPainter(this.color, {required this.drop});

  final Color color;
  final bool drop;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / 100, size.height / 130);
    canvas
      ..translate(
        (size.width - 100 * scale) / 2,
        (size.height - 130 * scale) / 2,
      )
      ..scale(scale);
    final paint = Paint()..color = color;
    final stem = Path()
      ..moveTo(23, 12)
      ..lineTo(35, 12)
      ..lineTo(35, 100)
      ..lineTo(29, 116)
      ..lineTo(23, 100)
      ..close();
    final bowl = Path()
      ..moveTo(35, 12)
      ..cubicTo(68, 12, 88, 32, 88, 57)
      ..cubicTo(88, 84, 66, 100, 35, 100)
      ..lineTo(35, 91)
      ..cubicTo(58, 90, 74, 77, 74, 57)
      ..cubicTo(74, 35, 58, 21, 35, 21)
      ..close();
    canvas
      ..drawPath(stem, paint)
      ..drawPath(bowl, paint);
    if (drop) {
      final drip = Path()
        ..moveTo(29, 119)
        ..cubicTo(31, 122, 32.5, 124, 32.5, 125.5)
        ..arcToPoint(
          const Offset(25.5, 125.5),
          radius: const Radius.circular(3.5),
        )
        ..cubicTo(25.5, 124, 27, 122, 29, 119)
        ..close();
      canvas.drawPath(drip, Paint()..color = InkSlotColors.copper);
    }
  }

  @override
  bool shouldRepaint(_DPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.drop != drop;
}
