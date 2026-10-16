import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_kit.dart';
import '../../../core/widgets/inkslot_motion.dart';
import 'public_entry_controller.dart';

class PublicSplashPage extends StatefulWidget {
  const PublicSplashPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<PublicSplashPage> createState() => _PublicSplashPageState();
}

class _PublicSplashPageState extends State<PublicSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: InkSlotMotion.splash,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final entry = context.read<PublicEntryController>();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    entry.start(reduceMotion: reduceMotion, onComplete: widget.onFinished);
    if (reduceMotion) {
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: Stack(
      fit: StackFit.expand,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => _SplashStage(
            seconds:
                _controller.value * InkSlotMotion.splash.inMilliseconds / 1000,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 44,
          child: Center(
            child: Semantics(
              button: true,
              label: 'Saltar introducción',
              child: InkSlotPress(
                onTap: context.read<PublicEntryController>().skip,
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Center(
                      child: Text(
                        'SALTAR INTRO',
                        style: inkSlotMono(
                          size: 10,
                          color: const Color(0xFF807B74),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Positioned.fill(
          child: RepaintBoundary(child: InkSlotGrain(opacity: .06)),
        ),
      ],
    ),
  );
}

double _segment(
  double t,
  double delay,
  double duration, [
  Curve curve = Curves.linear,
]) => curve.transform(((t - delay) / duration).clamp(0.0, 1.0));

/// Escena del splash a partir del tiempo transcurrido (4.6 s): moneda D en
/// 8 capas con profundidad, trazo, gota, ondas, haz, halo y wordmark.
class _SplashStage extends StatelessWidget {
  const _SplashStage({required this.seconds});

  final double seconds;

  @override
  Widget build(BuildContext context) {
    final t = seconds;
    final exit = _segment(t, 4, .7, const Cubic(.6, 0, .4, 1));
    final size = MediaQuery.sizeOf(context);

    Widget scene = Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _BeamPainter(
            _segment(t, .2, 2.6, const Cubic(.4, 0, .2, 1)),
          ),
        ),
        CustomPaint(
          painter: _HaloPainter(
            opacity: _segment(t, 1.3, 2.4, Curves.easeOut),
            center: Offset(size.width / 2, size.height * .41),
          ),
        ),
        CustomPaint(
          painter: _CoinPainter(t, Offset(size.width / 2, size.height * .41)),
        ),
        CustomPaint(
          painter: _RipplePainter(
            _segment(t, 2.5, 1.4, Curves.easeOut),
            Offset(size.width / 2, size.height * .41 + 150),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: size.height * .66,
          child: _Wordmark(t: t),
        ),
      ],
    );
    if (exit > 0) {
      scene = Opacity(
        opacity: 1 - exit,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 6 * exit, sigmaY: 6 * exit),
          child: Transform.scale(scale: 1 + .06 * exit, child: scene),
        ),
      );
    }
    return ClipRect(child: scene);
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.t});

  final double t;

  @override
  Widget build(BuildContext context) {
    final wm = _segment(t, 2.3, 1.4, InkSlotMotion.standard);
    final em = 1.6 + (.9 - 1.6) * wm;
    final sub = _segment(t, 2.9, .9, InkSlotMotion.standard);
    Widget title = Opacity(
      opacity: wm,
      child: Padding(
        padding: const EdgeInsets.only(left: 15 * .9),
        child: Text(
          'DODOGIO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Geist Mono',
            fontSize: 15,
            letterSpacing: 15 * em,
            color: InkSlotColors.bone,
          ),
        ),
      ),
    );
    if (wm > 0 && wm < 1) {
      title = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 6 * (1 - wm),
          sigmaY: 6 * (1 - wm),
        ),
        child: title,
      );
    }
    return Column(
      children: [
        title,
        const SizedBox(height: 14),
        Opacity(
          opacity: sub,
          child: Transform.translate(
            offset: Offset(0, (1 - sub) * 18),
            child: Text(
              'Tu cita, en un solo trazo.',
              textAlign: TextAlign.center,
              style: inkSlotSerif(
                20,
                color: InkSlotColors.ash,
                italic: true,
                height: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width * .8;
    final height = size.height * 1.4;
    final left = size.width * (-.6 + 1.8 * progress);
    final rect = Rect.fromLTWH(left, -size.height * .2, width, height);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(14 * math.pi / 180);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    canvas.drawRect(
      local,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-1, -.18),
          end: Alignment(1, .18),
          colors: [
            Color(0x00000000),
            Color(0x00EEE9E0),
            Color(0x21E2A062),
            Color(0x00EEE9E0),
            Color(0x00000000),
          ],
          stops: [0, .3, .5, .7, 1],
        ).createShader(local),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeamPainter old) => old.progress != progress;
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.opacity, required this.center});

  final double opacity;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final rect = Rect.fromCircle(center: center, radius: 210);
    canvas.drawCircle(
      center,
      210,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(200, 121, 57, .18 * opacity),
            const Color(0x00C87939),
          ],
          stops: const [0, .6],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) =>
      old.opacity != opacity || old.center != center;
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.progress, this.center);

  final double progress;
  final Offset center;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final sx = .2 + (14 - .2) * progress;
    final sy = .2 + (4 - .2) * progress;
    final opacity = .9 * (1 - progress);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 12 * sx, height: 12 * sy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.fromRGBO(200, 121, 57, .8 * opacity / .9),
    );
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

final Path _stem = Path()
  ..moveTo(23, 12)
  ..lineTo(35, 12)
  ..lineTo(35, 100)
  ..lineTo(29, 116)
  ..lineTo(23, 100)
  ..close();

final Path _bowl = Path()
  ..moveTo(35, 12)
  ..cubicTo(68, 12, 88, 32, 88, 57)
  ..cubicTo(88, 84, 66, 100, 35, 100)
  ..lineTo(35, 91)
  ..cubicTo(58, 90, 74, 77, 74, 57)
  ..cubicTo(74, 35, 58, 21, 35, 21)
  ..close();

final Path _highlight = Path()
  ..moveTo(42, 31)
  ..cubicTo(57, 33, 65, 44, 65, 57);

final Path _dropPath = Path()
  ..moveTo(29, 119)
  ..cubicTo(31, 122, 32.5, 124, 32.5, 125.5)
  ..arcToPoint(
    const Offset(25.5, 125.5),
    radius: const Radius.circular(3.5),
    clockwise: true,
  )
  ..cubicTo(25.5, 124, 27, 122, 29, 119)
  ..close();

const List<(double, Color)> _depthLayers = [
  (-14, Color(0xFF0E0D0C)),
  (-12, Color(0xFF13110F)),
  (-10, Color(0xFF181614)),
  (-8, Color(0xFF1E1B18)),
  (-6, Color(0xFF25211D)),
  (-4, Color(0xFF2D2823)),
  (-2, Color(0xFF3A342E)),
];

/// `.coin`: 8 capas con `translateZ`, `coinIn` (2.6 s) y `sway` (6 s).
class _CoinPainter extends CustomPainter {
  _CoinPainter(this.t, this.center);

  final double t;
  final Offset center;

  static const _w = 200.0;
  static const _h = 260.0;

  Matrix4 _layerMatrix(double z) {
    final coin = _segment(t, 0, 2.6, InkSlotMotion.threeDimension);
    var ry = -95 + (-16 - -95) * coin;
    var rx = 24 + (6 - 24) * coin;
    final scale = .6 + .4 * coin;
    if (t > 2.6) {
      final phase = ((t - 2.6) / 6) % 2;
      final p = Curves.easeInOut.transform(phase <= 1 ? phase : 2 - phase);
      ry = -16 + (14 - -16) * p;
      rx = 6 + (-4 - 6) * p;
    }
    final perspective = Matrix4.identity()..setEntry(3, 2, -1 / 900);
    final m = Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(perspective)
      ..rotateY(ry * math.pi / 180)
      ..rotateX(rx * math.pi / 180)
      ..scaleByDouble(scale, scale, scale, 1)
      ..translateByDouble(0, 0, z, 1)
      ..translateByDouble(-_w / 2, -_h / 2, 0, 1)
      ..scaleByDouble(2, 2, 1, 1);
    return m;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final layer in _depthLayers) {
      canvas.save();
      canvas.transform(_layerMatrix(layer.$1).storage);
      final paint = Paint()..color = layer.$2;
      canvas.drawPath(_stem, paint);
      canvas.drawPath(_bowl, paint);
      canvas.restore();
    }

    canvas.save();
    canvas.transform(_layerMatrix(0).storage);
    final draw = _segment(t, .35, 1.5, const Cubic(.6, 0, .2, 1));
    final fill = _segment(t, 1.55, .7, Curves.ease);
    final highlight = _segment(t, 1.9, 1.5, const Cubic(.6, 0, .2, 1));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = InkSlotColors.bone;
    for (final path in [_stem, _bowl]) {
      if (fill > 0) {
        canvas.drawPath(
          path,
          Paint()..color = InkSlotColors.bone.withValues(alpha: fill),
        );
      }
      if (draw > 0) canvas.drawPath(_partial(path, draw), stroke);
    }
    if (highlight > 0) {
      canvas.drawPath(
        _partial(_highlight, highlight),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = InkSlotColors.ink,
      );
    }
    _paintDrop(canvas);
    canvas.restore();
  }

  void _paintDrop(Canvas canvas) {
    final p = ((t - 2.05) / 1.1).clamp(0.0, 1.0);
    if (p <= 0) return;
    const ease = Cubic(.5, 0, .75, 0);
    double opacity, dy, sy;
    if (p < .2) {
      final k = ease.transform(p / .2);
      opacity = k;
      dy = -6 * (1 - k);
      sy = .4 + (1.4 - .4) * k;
    } else {
      final k = ease.transform((p - .2) / .8);
      opacity = 1;
      dy = 0;
      sy = 1.4 + (1 - 1.4) * k;
    }
    final bounds = _dropPath.getBounds();
    canvas.save();
    canvas.translate(bounds.center.dx, bounds.top + dy);
    canvas.scale(1, sy);
    canvas.translate(-bounds.center.dx, -bounds.top);
    canvas.drawPath(
      _dropPath,
      Paint()..color = InkSlotColors.copper.withValues(alpha: opacity),
    );
    canvas.restore();
  }

  Path _partial(Path path, double fraction) {
    final out = Path();
    for (final metric in path.computeMetrics()) {
      out.addPath(metric.extractPath(0, metric.length * fraction), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(_CoinPainter old) => old.t != t || old.center != center;
}
