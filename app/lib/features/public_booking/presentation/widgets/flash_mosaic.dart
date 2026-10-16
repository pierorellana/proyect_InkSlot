import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_kit.dart';

const _tileHeight = 200.0;
const _tileGap = 14.0;
const _tilesPerColumn = 12;
const _period = 6 * (_tileHeight + _tileGap);

const _labels = <String>[
  'Rosa · fineline',
  'Daga · blackwork',
  'Ojo · flash',
  'Luna · fineline',
  'Corazón · old school',
  'Polilla · dotwork',
];

enum _TileTone { base, inverse, oxide }

/// `.mq`: mosaico de flash inclinado -13° en tres columnas con scroll
/// infinito (`up` 40 s, `dn` 46 s) y fundido inferior de 260 px.
class FlashMosaic extends StatefulWidget {
  const FlashMosaic({super.key});

  @override
  State<FlashMosaic> createState() => _FlashMosaicState();
}

class _FlashMosaicState extends State<FlashMosaic>
    with TickerProviderStateMixin {
  late final AnimationController _up = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );
  late final AnimationController _down = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 46),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!MediaQuery.disableAnimationsOf(context)) {
      _up.repeat();
      _down.repeat();
    }
  }

  @override
  void dispose() {
    _up.dispose();
    _down.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: 470,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: -90,
              height:
                  _tilesPerColumn * _tileHeight +
                  (_tilesPerColumn - 1) * _tileGap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 418.0;
                  final mosaicWidth = math.max(540.0, availableWidth + 150);

                  return OverflowBox(
                    alignment: Alignment.topCenter,
                    minWidth: mosaicWidth,
                    maxWidth: mosaicWidth,
                    child: SizedBox(
                      width: mosaicWidth,
                      child: Transform.translate(
                        offset: const Offset(-70, 0),
                        child: Transform.rotate(
                          angle: -13 * math.pi / 180,
                          alignment: Alignment.topCenter,
                          child: Row(
                            key: const ValueKey('flash-mosaic-columns'),
                            children: [
                              Expanded(
                                child: _MosaicColumn(
                                  animation: _up,
                                  offset: 0,
                                  reverse: false,
                                ),
                              ),
                              const SizedBox(width: _tileGap),
                              Expanded(
                                child: _MosaicColumn(
                                  animation: _down,
                                  offset: 2,
                                  reverse: true,
                                ),
                              ),
                              const SizedBox(width: _tileGap),
                              Expanded(
                                child: _MosaicColumn(
                                  animation: _up,
                                  offset: 4,
                                  reverse: false,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 260,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000A0A0B), InkSlotColors.ink],
                    stops: [0, .82],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MosaicColumn extends StatelessWidget {
  const _MosaicColumn({
    required this.animation,
    required this.offset,
    required this.reverse,
  });

  final Animation<double> animation;
  final int offset;
  final bool reverse;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        final dy = reverse ? -_period + t * _period : -t * _period;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _tilesPerColumn; i++) ...[
            if (i > 0) const SizedBox(height: _tileGap),
            _FlashTile(
              index: (i % 6 + offset) % 6,
              slot: (i % 6) + offset + (reverse ? 6 : 0),
            ),
          ],
        ],
      ),
    ),
  );
}

class _FlashTile extends StatelessWidget {
  const _FlashTile({required this.index, required this.slot});

  final int index;
  final int slot;

  @override
  Widget build(BuildContext context) {
    final tone = slot % 5 == 2
        ? _TileTone.inverse
        : (slot % 7 == 4 ? _TileTone.oxide : _TileTone.base);
    final background = switch (tone) {
      _TileTone.base => const Color(0xFF141416),
      _TileTone.inverse => const Color(0xFFE6E0D5),
      _TileTone.oxide => InkSlotColors.tobacco,
    };
    final foreground = tone == _TileTone.inverse
        ? const Color(0xFF151416)
        : InkSlotColors.bone;
    return Container(
      height: _tileHeight,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(InkSlotRadii.mosaic),
        border: Border.all(color: const Color(0x0FEEE9E0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            InkSlotAssets.flashes[index],
            width: 78,
            height: 78,
            colorFilter: ColorFilter.mode(foreground, BlendMode.srcIn),
          ),
          const SizedBox(height: 12),
          Text(
            _labels[index].toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: inkSlotMono(
              size: 9,
              color: foreground.withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }
}
