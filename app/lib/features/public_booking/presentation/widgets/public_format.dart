import 'public_time_zone_formatter.dart';

const publicWeekdaysLong = <String>[
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

const publicWeekdaysShort = <String>[
  'lun',
  'mar',
  'mié',
  'jue',
  'vie',
  'sáb',
  'dom',
];

const publicMonths = <String>[
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

String publicCapitalize(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

String publicMonthShort(int monthIndex) =>
    publicMonths[monthIndex].substring(0, 3);

/// Fecha local de un instante UTC en la zona del estudio (índices 0-based,
/// lunes = 0).
class PublicDateParts {
  const PublicDateParts({
    required this.weekday,
    required this.day,
    required this.month,
    required this.year,
  });

  final int weekday;
  final int day;
  final int month;
  final int year;

  String get weekdayLong => publicWeekdaysLong[weekday];
  String get weekdayShort => publicWeekdaysShort[weekday];
  String get monthLong => publicMonths[month];
  String get monthShort => publicMonthShort(month);
}

PublicDateParts publicDateParts(DateTime utc, String timezone) {
  final match = RegExp(
    r'^([^,]+), (\d{1,2}) de ([^ ]+) de (\d{4})$',
  ).firstMatch(formatPublicDate(utc, timezone).trim().toLowerCase());
  if (match != null) {
    final weekday = publicWeekdaysLong.indexOf(match.group(1)!);
    final month = publicMonths.indexOf(match.group(3)!);
    if (weekday >= 0 && month >= 0) {
      return PublicDateParts(
        weekday: weekday,
        day: int.parse(match.group(2)!),
        month: month,
        year: int.parse(match.group(4)!),
      );
    }
  }
  final fallback = utc.toLocal();
  return PublicDateParts(
    weekday: fallback.weekday - 1,
    day: fallback.day,
    month: fallback.month - 1,
    year: fallback.year,
  );
}

/// `3 horas` / `1 hora` / `2h 30m`.
String publicDurationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (remainder == 0) return hours == 1 ? '1 hora' : '$hours horas';
  return '${hours}h ${remainder}m';
}

/// `3 h` / `2 h 30 min`.
String publicDurationShort(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0) return '$remainder min';
  if (remainder == 0) return '$hours h';
  return '$hours h $remainder min';
}

/// `Ecuador` para America/Guayaquil; el resto muestra la ciudad.
String publicZoneName(String timezone) => switch (timezone) {
  'America/Guayaquil' => 'Ecuador',
  'America/Lima' => 'Perú',
  'America/Bogota' => 'Colombia',
  _ => timezone.split('/').last.replaceAll('_', ' '),
};

/// `hora de Ecuador (GMT-5)` cuando el desfase es conocido.
String publicZoneDescription(String timezone) {
  final name = 'hora de ${publicZoneName(timezone)}';
  final gmt = switch (timezone) {
    'America/Guayaquil' ||
    'America/Lima' ||
    'America/Bogota' ||
    'America/New_York' => 'GMT-5',
    'America/Chicago' => 'GMT-6',
    'America/Denver' => 'GMT-7',
    'America/Los_Angeles' => 'GMT-8',
    'UTC' || 'GMT' || 'Europe/London' => 'GMT',
    'Europe/Madrid' => 'GMT+1',
    _ => null,
  };
  return gmt == null ? name : '$name ($gmt)';
}

/// Texto `vence en N h` desde el instante de expiración.
String publicExpiryLabel(DateTime expiresAt, {DateTime? now}) {
  final remaining = expiresAt.difference(now ?? DateTime.now().toUtc());
  if (remaining.inMinutes <= 0) return 'vence hoy';
  final hours = (remaining.inMinutes / 60).ceil();
  if (hours < 100) return 'vence en $hours h';
  return 'vence en ${(hours / 24).ceil()} días';
}
