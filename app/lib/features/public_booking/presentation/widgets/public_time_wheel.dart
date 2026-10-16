import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../domain/public_availability.dart';

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
  final ValueChanged<AvailabilitySlot> onSelected;

  @override
  State<PublicTimeWheel> createState() => _PublicTimeWheelState();
}

class _PublicTimeWheelState extends State<PublicTimeWheel> {
  late FixedExtentScrollController _scrollController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexFor(widget.slots, widget.selectedSlot);
    _scrollController = FixedExtentScrollController(
      initialItem: _selectedIndex,
    );
  }

  @override
  void didUpdateWidget(covariant PublicTimeWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _indexFor(widget.slots, widget.selectedSlot);
    if (nextIndex != _selectedIndex ||
        oldWidget.slots.length != widget.slots.length) {
      _selectedIndex = nextIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _jumpTo(_selectedIndex);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slots.isEmpty) {
      return const SizedBox.shrink();
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Horarios disponibles en ${widget.timezone}',
      child: Column(
        children: [
          IconButton(
            onPressed: _selectedIndex == 0
                ? null
                : () => _moveBy(-1, reduceMotion),
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            tooltip: 'Horario anterior',
            constraints: const BoxConstraints(
              minWidth: InkSlotSpacing.minimumTapTarget,
              minHeight: InkSlotSpacing.minimumTapTarget,
            ),
          ),
          SizedBox(
            height: 268,
            child: ListWheelScrollView.useDelegate(
              controller: _scrollController,
              itemExtent: 78,
              diameterRatio: 1.65,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                if (index < 0 || index >= widget.slots.length) return;
                setState(() => _selectedIndex = index);
                widget.onSelected(widget.slots[index]);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.slots.length,
                builder: (context, index) {
                  return _WheelSlotTile(
                    slot: widget.slots[index],
                    timezone: widget.timezone,
                    distance: index - _selectedIndex,
                    selected: index == _selectedIndex,
                    reduceMotion: reduceMotion,
                    onTap: () => _moveTo(index, reduceMotion),
                  );
                },
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            label:
                '${_formatSlotTime(widget.slots[_selectedIndex].startAt, widget.timezone)}, seleccionado',
            child: const SizedBox(width: 1, height: 1),
          ),
          IconButton(
            onPressed: _selectedIndex == widget.slots.length - 1
                ? null
                : () => _moveBy(1, reduceMotion),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            tooltip: 'Siguiente horario',
            constraints: const BoxConstraints(
              minWidth: InkSlotSpacing.minimumTapTarget,
              minHeight: InkSlotSpacing.minimumTapTarget,
            ),
          ),
        ],
      ),
    );
  }

  void _moveBy(int delta, bool reduceMotion) {
    _moveTo(
      (_selectedIndex + delta).clamp(0, widget.slots.length - 1).toInt(),
      reduceMotion,
    );
  }

  void _moveTo(int index, bool reduceMotion) {
    if (reduceMotion) {
      _jumpTo(index);
    } else {
      _scrollController.animateToItem(
        index,
        duration: InkSlotMotion.micro,
        curve: InkSlotMotion.threeDimension,
      );
    }
  }

  void _jumpTo(int index) {
    _scrollController.jumpToItem(index);
    if (index < 0 || index >= widget.slots.length) return;
    setState(() => _selectedIndex = index);
    widget.onSelected(widget.slots[index]);
  }
}

class _WheelSlotTile extends StatelessWidget {
  const _WheelSlotTile({
    required this.slot,
    required this.timezone,
    required this.distance,
    required this.selected,
    required this.reduceMotion,
    required this.onTap,
  });

  final AvailabilitySlot slot;
  final String timezone;
  final int distance;
  final bool selected;
  final bool reduceMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final normalizedDistance = distance.abs().clamp(0, 3).toDouble();
    final scale = selected ? 1.0 : 0.88 - (normalizedDistance * 0.025);
    final opacity = selected ? 1.0 : 0.48 - (normalizedDistance * 0.08);
    final angle = reduceMotion ? 0.0 : distance.clamp(-3, 3) * 0.075;
    final time = _formatSlotTime(slot.startAt, timezone);
    return Semantics(
      button: true,
      selected: selected,
      label: '$time, ${selected ? 'seleccionado' : 'disponible'}',
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateX(angle),
            child: Transform.scale(
              scale: scale,
              child: AnimatedOpacity(
                opacity: opacity.clamp(0.2, 1.0),
                duration: reduceMotion ? Duration.zero : InkSlotMotion.micro,
                child: AnimatedContainer(
                  duration: reduceMotion ? Duration.zero : InkSlotMotion.micro,
                  constraints: const BoxConstraints(
                    minWidth: 150,
                    minHeight: 54,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? InkSlotColors.copper : Colors.transparent,
                    borderRadius: BorderRadius.circular(InkSlotRadii.button),
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: InkSlotColors.copperGlow,
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ]
                        : null,
                    border: selected
                        ? null
                        : Border.all(color: InkSlotColors.lineSubtle),
                  ),
                  child: Text(
                    time,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? InkSlotColors.ink
                          : InkSlotColors.secondary,
                      fontSize: selected ? 28 : 22,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

int _indexFor(List<AvailabilitySlot> slots, AvailabilitySlot? target) {
  if (target == null) return 0;
  final index = slots.indexWhere(
    (slot) => slot.startAt == target.startAt && slot.endAt == target.endAt,
  );
  return index < 0 ? 0 : index;
}

String _formatSlotTime(DateTime utc, String timezone) {
  final local = utc.toUtc().add(
    Duration(minutes: _timezoneOffsetMinutes(timezone)),
  );
  return DateFormat('HH:mm').format(local);
}

int _timezoneOffsetMinutes(String timezone) => switch (timezone) {
  'UTC' || 'GMT' => 0,
  'America/Guayaquil' || 'America/Lima' || 'America/Bogota' => -300,
  'America/Los_Angeles' => -480,
  'America/Denver' => -420,
  'America/Chicago' => -360,
  'America/New_York' => -300,
  'Europe/London' => 0,
  'Europe/Madrid' => 60,
  _ => 0,
};
