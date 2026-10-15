import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/inkslot_tokens.dart';
import '../../../core/widgets/inkslot_logo.dart';
import 'public_entry_controller.dart';

class PublicSplashPage extends StatefulWidget {
  const PublicSplashPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<PublicSplashPage> createState() => _PublicSplashPageState();
}

class _PublicSplashPageState extends State<PublicSplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
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
    if (!reduceMotion) {
      _animationController.forward();
    } else {
      _animationController.value = 1;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: InkSlotColors.deep,
    body: Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) =>
                _SplashArtwork(progress: _animationController.value),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Center(
            child: Semantics(
              button: true,
              label: 'Saltar introducción',
              child: TextButton(
                onPressed: context.read<PublicEntryController>().skip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    InkSlotSpacing.minimumTapTarget,
                    InkSlotSpacing.minimumTapTarget,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text(
                  'SALTAR INTRO',
                  style: TextStyle(
                    color: InkSlotColors.ash,
                    fontFamily: 'Geist Mono',
                    fontSize: 11,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final coinProgress = Curves.easeOutCubic.transform(
      (progress / 0.34).clamp(0, 1),
    );
    final swayProgress = Curves.easeInOut.transform(
      ((progress - 0.18) / 0.62).clamp(0, 1),
    );
    final opacity = Curves.easeOut.transform(
      ((progress - 0.08) / 0.24).clamp(0, 1),
    );
    final wordmarkOpacity = Curves.easeOut.transform(
      ((progress - 0.52) / 0.22).clamp(0, 1),
    );
    final dropProgress = Curves.easeOutBack.transform(
      ((progress - 0.3) / 0.26).clamp(0, 1),
    );
    final angleY = -0.4 + (0.18 * swayProgress);
    final angleX = 0.1 - (0.17 * swayProgress);

    final logoTransform = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateY(angleY * (0.65 + (coinProgress * 0.35)))
      ..rotateX(angleX)
      ..scaleByDouble(
        0.72 + (0.28 * coinProgress),
        0.72 + (0.28 * coinProgress),
        0.72 + (0.28 * coinProgress),
        1,
      );

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          top: MediaQuery.sizeOf(context).height * 0.27,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: InkSlotColors.tobacco.withValues(alpha: 0.7),
                  blurRadius: 86,
                  spreadRadius: 12,
                ),
              ],
            ),
          ),
        ),
        Transform(
          alignment: Alignment.center,
          transform: logoTransform,
          child: Opacity(
            opacity: opacity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const InkSlotLogo(size: 190),
                Positioned(
                  bottom: -12 + (dropProgress * 2),
                  child: Transform.scale(
                    scale: 0.65 + (dropProgress * 0.35),
                    child: SvgPicture.asset(
                      InkSlotAssets.logoCopper,
                      width: 28,
                      height: 36,
                      colorFilter: ColorFilter.mode(
                        InkSlotColors.copper,
                        BlendMode.srcIn,
                      ),
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.sizeOf(context).height * 0.67,
          child: Opacity(
            opacity: wordmarkOpacity,
            child: const Text(
              'D O D O G I O',
              style: TextStyle(
                color: InkSlotColors.bone,
                fontFamily: 'Geist Mono',
                fontSize: 13,
                letterSpacing: 5.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
