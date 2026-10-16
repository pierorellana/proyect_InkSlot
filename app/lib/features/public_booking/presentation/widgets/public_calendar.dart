import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../../../core/widgets/inkslot_kit.dart';
import '../../../../core/widgets/inkslot_motion.dart';
import '../../domain/public_availability.dart';
import 'public_format.dart';

/// `.cal`: cabecera L M X J V S D y rejilla de días de 46 px de un mes.
class PublicCalendar extends StatelessWidget {
  const PublicCalendar({
    required this.month,
    required this.availableDays,
    required this.selectedDate,
    required this.onSelectDate,
    super.key,
    this.today,
  });

  /// Primer día del mes que se muestra.
  final DateTime month;
  final List<AvailabilityDay> availableDays;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = (first.weekday - DateTime.monday) % 7;
    final available = <String, AvailabilityDay>{
      for (final day in availableDays) _dateKey(day.date): day,
    };
    final now = today ?? DateTime.now();
    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var d = 1; d <= daysInMonth; d++)
        _cell(DateTime(month.year, month.month, d), available, now),
    ];
    final rows = (cells.length / 7).ceil();
    return Semantics(
      container: true,
      label: 'Calendario de disponibilidad',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final label in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: inkSlotMono(
                        size: 10,
                        color: const Color(0xFF807B74),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: 6),
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: r * 7 + c < cells.length
                        ? cells[r * 7 + c]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(
    DateTime date,
    Map<String, AvailabilityDay> available,
    DateTime now,
  ) {
    final day = available[_dateKey(date)];
    final slots = day?.slots.length ?? 0;
    final selected = selectedDate != null && _sameDate(selectedDate!, date);
    return _CalendarDay(
      date: date,
      slots: slots,
      isSelected: selected,
      isToday: _sameDate(now, date),
      onTap: slots > 0 ? () => onSelectDate(date) : null,
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.slots,
    required this.isSelected,
    required this.isToday,
    required this.onTap,
  });

  final DateTime date;
  final int slots;
  final bool isSelected;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = slots > 0;
    final label =
        '${publicWeekdaysLong[date.weekday - 1]} ${date.day} de '
        '${publicMonths[date.month - 1]}'
        '${available ? ', $slots horarios' : ', sin horarios'}';
    final foreground = isSelected
        ? InkSlotColors.ink
        : available
        ? InkSlotColors.bone
        : InkSlotColors.disabled;
    Widget body = AnimatedContainer(
      duration: inkSlotReduceMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isSelected ? InkSlotColors.copper : Colors.transparent,
        shape: BoxShape.circle,
        border: isToday && !isSelected
            ? Border.all(color: const Color(0x38EEE9E0))
            : null,
        boxShadow: isSelected
            ? const [
                BoxShadow(
                  color: Color(0x99C87939),
                  blurRadius: 22,
                  spreadRadius: -8,
                  offset: Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              color: foreground,
              fontSize: 16,
              height: 1.2,
              fontWeight: available ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
          if (available)
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(top: 3),
              decoration: BoxDecoration(
                color: isSelected ? InkSlotColors.ink : InkSlotColors.copper,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
    if (isSelected && !inkSlotReduceMotion(context)) {
      body = TweenAnimationBuilder<double>(
        key: ValueKey('pop-${date.day}'),
        tween: Tween(begin: .7, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: const Cubic(.2, 1.6, .4, 1),
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: body,
      );
    }
    return Semantics(
      button: true,
      enabled: available,
      selected: isSelected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(child: body),
      ),
    );
  }
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
