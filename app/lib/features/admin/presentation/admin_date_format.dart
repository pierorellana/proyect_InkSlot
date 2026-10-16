const _weekdaysShort = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _weekdaysFull = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
const _monthsShort = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String weekdayShort(DateTime date) => _weekdaysShort[date.weekday - 1];

String weekdayFull(DateTime date) => _weekdaysFull[date.weekday - 1];

String monthShort(DateTime date) => _monthsShort[date.month - 1];

/// `Jueves 15 oct`.
String longDayLabel(DateTime date) =>
    '${weekdayFull(date)} ${date.day} ${monthShort(date)}';

/// `sáb 17 oct`.
String shortDayLabel(DateTime date) =>
    '${weekdayShort(date).toLowerCase()} ${date.day} ${monthShort(date)}';

/// `3 h`, `1 h 30 min`, `45 min`.
String durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest min';
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

String clockLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';
