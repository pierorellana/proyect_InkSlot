class PublicConfirmation {
  const PublicConfirmation({
    required this.status,
    required this.syncStatus,
    required this.startAt,
    required this.endAt,
    required this.timezone,
  });

  final String status;
  final String syncStatus;
  final DateTime startAt;
  final DateTime endAt;
  final String timezone;

  factory PublicConfirmation.fromJson(Map<String, dynamic> json) {
    final status = _requiredString(json, 'status');
    if (status != 'confirmed') {
      throw const FormatException('El estado de confirmación no es válido.');
    }

    final syncStatus = _requiredString(json, 'syncStatus');
    if (!const {'pending', 'synced', 'failed'}.contains(syncStatus)) {
      throw const FormatException('El estado de sincronización no es válido.');
    }

    final startAt = _requiredUtcInstant(json, 'startAt');
    final endAt = _requiredUtcInstant(json, 'endAt');
    if (!startAt.isBefore(endAt)) {
      throw const FormatException('El intervalo confirmado no es válido.');
    }

    final timezone = _requiredString(json, 'timezone');
    if (!_looksLikeTimezone(timezone)) {
      throw const FormatException('La zona horaria confirmada no es válida.');
    }

    return PublicConfirmation(
      status: status,
      syncStatus: syncStatus,
      startAt: startAt,
      endAt: endAt,
      timezone: timezone,
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('El campo "$key" no tiene un texto válido.');
}

DateTime _requiredUtcInstant(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  if (!value.endsWith('Z')) {
    throw FormatException('El campo "$key" no tiene un instante UTC válido.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('El campo "$key" no tiene un instante UTC válido.');
  }
  return parsed;
}

bool _looksLikeTimezone(String value) =>
    value == 'UTC' ||
    value == 'GMT' ||
    (value.contains('/') && !value.contains(' '));
