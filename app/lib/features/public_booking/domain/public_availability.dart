class PublicAvailability {
  const PublicAvailability({required this.timezone, required this.days});

  final String timezone;
  final List<AvailabilityDay> days;

  factory PublicAvailability.fromJson(Map<String, dynamic> json) {
    final timezone = json['timezone'];
    final rawDays = json['days'];
    if (timezone is! String || !_looksLikeTimezone(timezone)) {
      throw const FormatException(
        'La zona horaria de disponibilidad no es válida.',
      );
    }
    if (rawDays is! List) {
      throw const FormatException('Los días de disponibilidad no son válidos.');
    }
    final days = rawDays
        .map((value) => AvailabilityDay.fromJson(_asMap(value, 'days[]')))
        .toList(growable: false);
    for (var index = 1; index < days.length; index++) {
      if (!days[index - 1].date.isBefore(days[index].date)) {
        throw const FormatException(
          'Los días de disponibilidad no están ordenados.',
        );
      }
    }
    return PublicAvailability(timezone: timezone, days: days);
  }
}

class AvailabilityDay {
  const AvailabilityDay({required this.date, required this.slots});

  final DateTime date;
  final List<AvailabilitySlot> slots;

  factory AvailabilityDay.fromJson(Map<String, dynamic> json) {
    final dateValue = json['date'];
    final rawSlots = json['slots'];
    if (dateValue is! String || rawSlots is! List) {
      throw const FormatException('El día de disponibilidad no es válido.');
    }
    final date = _parseDateOnly(dateValue, 'date');
    final slots = rawSlots
        .map((value) => AvailabilitySlot.fromJson(_asMap(value, 'slots[]')))
        .toList(growable: false);
    for (var index = 1; index < slots.length; index++) {
      if (!slots[index - 1].startAt.isBefore(slots[index].startAt)) {
        throw const FormatException('Los horarios no están ordenados.');
      }
    }
    return AvailabilityDay(date: date, slots: slots);
  }
}

class AvailabilitySlot {
  const AvailabilitySlot({required this.startAt, required this.endAt});

  final DateTime startAt;
  final DateTime endAt;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    final start = _requiredUtcInstant(json, 'startAt');
    final end = _requiredUtcInstant(json, 'endAt');
    if (!start.isBefore(end)) {
      throw const FormatException(
        'El intervalo de disponibilidad no es válido.',
      );
    }
    return AvailabilitySlot(startAt: start, endAt: end);
  }
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El elemento "$field" no tiene un objeto válido.');
}

DateTime _requiredUtcInstant(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || !value.endsWith('Z')) {
    throw FormatException('El campo "$key" no tiene un instante UTC válido.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('El campo "$key" no tiene un instante UTC válido.');
  }
  return parsed;
}

DateTime _parseDateOnly(String value, String field) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw FormatException('El campo "$field" no es válido.');
  final date = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final normalized =
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  if (normalized != value) {
    throw FormatException('El campo "$field" no es válido.');
  }
  return date;
}

bool _looksLikeTimezone(String value) =>
    value == 'UTC' ||
    value == 'GMT' ||
    (value.contains('/') && !value.contains(' '));
