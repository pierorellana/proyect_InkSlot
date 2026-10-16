import 'package:flutter/material.dart';

import '../../../../core/theme/inkslot_tokens.dart';
import '../../domain/public_availability.dart';

class PublicCalendar extends StatelessWidget {
  const PublicCalendar({
    required this.rangeStart,
    required this.rangeEnd,
    required this.availableDays,
    required this.selectedDate,
    required this.onSelectDate,
    super.key,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final List<AvailabilityDay> availableDays;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelectDate;

  @override
  Widget build(BuildContext context) {
    final dates = _datesInRange(rangeStart, rangeEnd);
    final leading = (rangeStart.weekday - DateTime.monday) % 7;
    final available = <String, AvailabilityDay>{
      for (final day in availableDays) _dateKey(day.date): day,
    };

    return Semantics(
      container: true,
      label: 'Calendario de disponibilidad',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        decoration: BoxDecoration(
          color: InkSlotColors.surface,
          borderRadius: BorderRadius.circular(InkSlotRadii.card),
          border: Border.all(color: InkSlotColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _monthLabel(rangeStart, rangeEnd),
                style: const TextStyle(
                  color: InkSlotColors.cream,
                  fontFamily: 'Instrument Serif',
                  fontSize: 27,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Row(
              children: [
                _WeekdayLabel('L'),
                _WeekdayLabel('M'),
                _WeekdayLabel('M'),
                _WeekdayLabel('J'),
                _WeekdayLabel('V'),
                _WeekdayLabel('S'),
                _WeekdayLabel('D'),
              ],
            ),
            const SizedBox(height: 5),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: leading + dates.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: 52,
              ),
              itemBuilder: (context, index) {
                if (index < leading) return const SizedBox.shrink();
                final date = dates[index - leading];
                final day = available[_dateKey(date)];
                final isAvailable = day != null && day.slots.isNotEmpty;
                final isSelected =
                    selectedDate != null && _sameDate(selectedDate!, date);
                return _CalendarDay(
                  date: date,
                  isAvailable: isAvailable,
                  isSelected: isSelected,
                  onTap: isAvailable ? () => onSelectDate(date) : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Center(
      child: Text(
        label,
        style: const TextStyle(
          color: InkSlotColors.tertiary,
          fontFamily: 'Geist Mono',
          fontSize: 11,
        ),
      ),
    ),
  );
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    required this.date,
    required this.isAvailable,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isAvailable;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = '${_weekdayName(date.weekday)} ${date.day}';
    final foreground = isSelected
        ? InkSlotColors.ink
        : isAvailable
        ? InkSlotColors.cream
        : InkSlotColors.disabled;
    return Semantics(
      button: true,
      enabled: isAvailable,
      selected: isSelected,
      label: isAvailable ? '$label, disponible' : '$label, no disponible',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InkSlotRadii.chip),
        child: Center(
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : InkSlotMotion.micro,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? InkSlotColors.copper : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? InkSlotColors.copperLight
                    : Colors.transparent,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 15,
                    fontWeight: isSelected || isAvailable
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (isAvailable && !isSelected)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: InkSlotColors.copper,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

List<DateTime> _datesInRange(DateTime start, DateTime end) {
  final dates = <DateTime>[];
  for (
    var date = DateTime(start.year, start.month, start.day);
    !date.isAfter(end);
    date = date.add(const Duration(days: 1))
  ) {
    dates.add(date);
  }
  return dates;
}

String _monthLabel(DateTime start, DateTime end) {
  const months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final first = '${months[start.month - 1]} ${start.year}';
  final last = '${months[end.month - 1]} ${end.year}';
  return first == last ? _capitalize(first) : '${_capitalize(first)} — $last';
}

String _capitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String _weekdayName(int weekday) => const <String>[
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
][weekday - 1];

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
