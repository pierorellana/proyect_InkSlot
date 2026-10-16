class PublicReservation {
  const PublicReservation({
    required this.status,
    required this.artistDisplayName,
    required this.durationMinutes,
    required this.timezone,
    required this.restrictions,
    required this.expiresAt,
  });

  final String status;
  final String artistDisplayName;
  final int durationMinutes;
  final String timezone;
  final PublicRestrictions restrictions;
  final DateTime expiresAt;

  bool get isPending => status == 'pending';
  bool get isBooked => status == 'booked';

  factory PublicReservation.fromJson(Map<String, dynamic> json) {
    final artist = _requiredMap(json, 'artist');
    final restrictions = _requiredMap(json, 'restrictions');
    final status = _requiredString(json, 'status');
    if (status != 'pending' && status != 'booked') {
      throw const FormatException('El estado público no es válido.');
    }

    final duration = _requiredInt(json, 'durationMinutes');
    if (duration <= 0) {
      throw const FormatException('La duración pública no es válida.');
    }

    final timezone = _requiredString(json, 'timezone');
    if (!_looksLikeTimezone(timezone)) {
      throw const FormatException('La zona horaria pública no es válida.');
    }

    return PublicReservation(
      status: status,
      artistDisplayName: _nonEmptyString(artist, 'displayName'),
      durationMinutes: duration,
      timezone: timezone,
      restrictions: PublicRestrictions.fromJson(restrictions),
      expiresAt: _requiredInstant(json, 'expiresAt'),
    );
  }
}

class PublicRestrictions {
  const PublicRestrictions({
    required this.minDate,
    required this.maxDate,
    required this.allowedWeekdays,
    required this.allowedWindows,
  });

  final DateTime? minDate;
  final DateTime? maxDate;
  final List<int>? allowedWeekdays;
  final List<PublicRestrictionWindow>? allowedWindows;

  factory PublicRestrictions.fromJson(Map<String, dynamic> json) {
    final weekdays = _nullableList(json, 'allowedWeekdays')
        ?.map((value) {
          if (value is! int || value < 0 || value > 6) {
            throw const FormatException('Los días permitidos no son válidos.');
          }
          return value;
        })
        .toList(growable: false);
    if (weekdays != null && weekdays.toSet().length != weekdays.length) {
      throw const FormatException('Los días permitidos están repetidos.');
    }

    final windows = _nullableList(json, 'allowedWindows')
        ?.map((value) {
          return PublicRestrictionWindow.fromJson(
            _asMap(value, 'allowedWindows[]'),
          );
        })
        .toList(growable: false);

    return PublicRestrictions(
      minDate: _nullableDateOnly(json, 'minDate'),
      maxDate: _nullableDateOnly(json, 'maxDate'),
      allowedWeekdays: weekdays,
      allowedWindows: windows,
    );
  }
}

class PublicRestrictionWindow {
  const PublicRestrictionWindow({
    required this.startLocal,
    required this.endLocal,
  });

  final String startLocal;
  final String endLocal;

  factory PublicRestrictionWindow.fromJson(Map<String, dynamic> json) {
    final start = _requiredString(json, 'startLocal');
    final end = _requiredString(json, 'endLocal');
    final startMinutes = _clockMinutes(start);
    final endMinutes = _clockMinutes(end);
    if (startMinutes >= endMinutes) {
      throw const FormatException('La ventana pública no es válida.');
    }
    return PublicRestrictionWindow(startLocal: start, endLocal: end);
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El campo "$key" no tiene un objeto válido.');
}

List<dynamic>? _nullableList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is List) return value;
  throw FormatException('El campo "$key" no tiene una lista válida.');
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El elemento "$field" no tiene un objeto válido.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('El campo "$key" no tiene un texto válido.');
}

String _nonEmptyString(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key).trim();
  if (value.isEmpty) throw FormatException('El campo "$key" está vacío.');
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('El campo "$key" no tiene un entero válido.');
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('El campo "$key" no tiene un instante UTC válido.');
  }
  return parsed;
}

DateTime? _nullableDateOnly(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('El campo "$key" no tiene una fecha válida.');
  }
  return _parseDateOnly(value, key);
}

DateTime _parseDateOnly(String value, String field) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('El campo "$field" no tiene una fecha válida.');
  }
  final date = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (_dateKey(date) != value) {
    throw FormatException('El campo "$field" no tiene una fecha válida.');
  }
  return date;
}

int _clockMinutes(String value) {
  final match = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').firstMatch(value);
  if (match == null) throw const FormatException('La hora no es válida.');
  return int.parse(value.substring(0, 2)) * 60 + int.parse(value.substring(3));
}

bool _looksLikeTimezone(String value) {
  if (value == 'UTC' || value == 'GMT') return true;
  return value.contains('/') && !value.contains(' ');
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
