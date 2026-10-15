import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_logo.dart';

class FlashMosaic extends StatefulWidget {
  const FlashMosaic({super.key});

  @override
  State<FlashMosaic> createState() => _FlashMosaicState();
}

class _FlashMosaicState extends State<FlashMosaic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 370,
    child: ClipRect(
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) =>
                _MosaicCards(progress: _controller.value),
          ),
          const _MosaicFade(),
          Positioned(
            top: 16,
            left: 20,
            right: 20,
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    color: InkSlotColors.bone,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: InkSlotLogo(
                      color: InkSlotColors.ink,
                      size: 20,
                      semanticsLabel: 'InkSlot',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'DODOGIO',
                  style: TextStyle(
                    color: InkSlotColors.bone,
                    fontFamily: 'Geist Mono',
                    fontSize: 13,
                    letterSpacing: 4.4,
                  ),
                ),
                const Spacer(),
                Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: InkSlotColors.lineStrong),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: InkSlotColors.secondary,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ENLACE PRIVADO',
                        style: TextStyle(
                          color: InkSlotColors.secondary,
                          fontFamily: 'Geist Mono',
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _MosaicCards extends StatelessWidget {
  const _MosaicCards({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 560.0);
    final drift = (progress * 2 - 1) * 10;

    return Stack(
      children: [
        Positioned(
          left: -68,
          top: 120 + drift,
          child: _FlashCard(asset: InkSlotAssets.flashes[4], label: 'CORAZÓN'),
        ),
        Positioned(
          left: width * 0.12,
          top: -22 - drift,
          child: _FlashCard(asset: InkSlotAssets.flashes[5], label: 'POLILLA'),
        ),
        Positioned(
          left: width * 0.6,
          top: 82 + (drift * 0.4),
          child: _FlashCard(asset: InkSlotAssets.flashes[0], label: 'ROSA'),
        ),
        Positioned(
          left: width * 0.08,
          top: 226 - drift,
          child: _FlashCard(asset: InkSlotAssets.flashes[1], label: 'DAGA'),
        ),
        Positioned(
          left: width * 0.62,
          top: 252 + (drift * 0.5),
          child: _FlashCard(asset: InkSlotAssets.flashes[2], label: 'OJO'),
        ),
      ],
    );
  }
}

class _FlashCard extends StatelessWidget {
  const _FlashCard({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -0.12,
    child: Container(
      width: 154,
      height: 192,
      decoration: BoxDecoration(
        color: InkSlotColors.surface,
        borderRadius: BorderRadius.circular(InkSlotRadii.mosaic),
        border: Border.all(color: InkSlotColors.lineSubtle),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(asset, width: 70, height: 70),
          const SizedBox(height: 20),
          Text(
            label,
            style: const TextStyle(
              color: InkSlotColors.tertiary,
              fontFamily: 'Geist Mono',
              fontSize: 10,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MosaicFade extends StatelessWidget {
  const _MosaicFade();

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              InkSlotColors.deep.withValues(alpha: 0),
              InkSlotColors.deep.withValues(alpha: 0.05),
              InkSlotColors.deep,
            ],
            stops: const [0.42, 0.67, 1],
          ),
        ),
      ),
    ),
  );
}
