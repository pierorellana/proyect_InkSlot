enum AdminAppointmentStatus {
  confirmed,
  completed,
  cancelled,
  noShow;

  String get apiValue => switch (this) {
    AdminAppointmentStatus.confirmed => 'confirmed',
    AdminAppointmentStatus.completed => 'completed',
    AdminAppointmentStatus.cancelled => 'cancelled',
    AdminAppointmentStatus.noShow => 'no_show',
  };

  static AdminAppointmentStatus fromApi(Object? value) {
    if (value is! String) {
      throw const FormatException('El estado de la cita no es válido.');
    }
    return switch (value) {
      'confirmed' => AdminAppointmentStatus.confirmed,
      'completed' => AdminAppointmentStatus.completed,
      'cancelled' => AdminAppointmentStatus.cancelled,
      'no_show' => AdminAppointmentStatus.noShow,
      _ => throw FormatException(
        'El API devolvió un estado de cita desconocido: $value.',
      ),
    };
  }
}

enum AdminAppointmentSyncStatus {
  pending,
  synced,
  failed;

  static AdminAppointmentSyncStatus fromApi(Object? value) {
    if (value is! String) {
      throw const FormatException(
        'El estado de sincronización de la cita no es válido.',
      );
    }
    return switch (value) {
      'pending' => AdminAppointmentSyncStatus.pending,
      'synced' => AdminAppointmentSyncStatus.synced,
      'failed' => AdminAppointmentSyncStatus.failed,
      _ => throw FormatException(
        'El API devolvió un estado de sincronización desconocido: $value.',
      ),
    };
  }
}

class AdminAppointment {
  const AdminAppointment({
    required this.id,
    required this.clientName,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.status,
    required this.syncStatus,
    required this.version,
  });

  final String id;
  final String clientName;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final AdminAppointmentStatus status;
  final AdminAppointmentSyncStatus syncStatus;
  final int version;

  factory AdminAppointment.fromJson(Map<String, dynamic> json) {
    final client = _requiredMap(json, 'client');
    return AdminAppointment(
      id: _requiredString(json, 'id'),
      clientName: _requiredString(client, 'name'),
      startAt: _requiredDate(json, 'startAt'),
      endAt: _requiredDate(json, 'endAt'),
      durationMinutes: _requiredInt(json, 'durationMinutes'),
      status: AdminAppointmentStatus.fromApi(json['status']),
      syncStatus: AdminAppointmentSyncStatus.fromApi(json['syncStatus']),
      version: _requiredInt(json, 'version'),
    );
  }
}

class AdminAppointmentPage {
  const AdminAppointmentPage({required this.items, required this.nextCursor});

  final List<AdminAppointment> items;
  final String? nextCursor;

  factory AdminAppointmentPage.fromJson(Map<String, dynamic> json) {
    final value = json['items'];
    if (value is! List) {
      throw const FormatException(
        'El campo "items" no tiene una lista válida.',
      );
    }
    return AdminAppointmentPage(
      items: value
          .map((item) => AdminAppointment.fromJson(_asMap(item, 'items[]')))
          .toList(growable: false),
      nextCursor: _nullableString(json, 'nextCursor'),
    );
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El campo "$key" no tiene un objeto válido.');
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El elemento "$field" no tiene un objeto válido.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('El campo "$key" no tiene un texto válido.');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('El campo "$key" no tiene un cursor válido.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('El campo "$key" no tiene un entero válido.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException('El campo "$key" no tiene una fecha válida.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('El campo "$key" no tiene una fecha válida.');
  }
  return parsed;
}
