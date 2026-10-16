class AdminDashboard {
  const AdminDashboard({
    required this.pendingRequests,
    required this.upcomingAppointments,
    required this.syncIssues,
    required this.nextAppointments,
  });

  final int pendingRequests;
  final int upcomingAppointments;
  final int syncIssues;
  final List<DashboardAppointment> nextAppointments;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) {
    final appointments = _requiredList(json, 'nextAppointments');

    return AdminDashboard(
      pendingRequests: _requiredCount(json, 'pendingRequests'),
      upcomingAppointments: _requiredCount(json, 'upcomingAppointments'),
      syncIssues: _requiredCount(json, 'syncIssues'),
      nextAppointments: appointments
          .map((appointment) {
            return DashboardAppointment.fromJson(
              _asMap(appointment, 'nextAppointments[]'),
            );
          })
          .toList(growable: false),
    );
  }
}

class DashboardAppointment {
  const DashboardAppointment({
    required this.id,
    required this.client,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.status,
    required this.syncStatus,
  });

  final String id;
  final DashboardClient client;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final String status;
  final String syncStatus;

  factory DashboardAppointment.fromJson(Map<String, dynamic> json) {
    final startAt = _requiredIsoDate(json, 'startAt');
    final endAt = _requiredIsoDate(json, 'endAt');
    if (!endAt.isAfter(startAt)) {
      throw const FormatException('El intervalo de la cita no es válido.');
    }

    return DashboardAppointment(
      id: _requiredNonEmptyString(json, 'id'),
      client: DashboardClient.fromJson(_requiredMap(json, 'client')),
      startAt: startAt,
      endAt: endAt,
      durationMinutes: _requiredPositiveInt(json, 'durationMinutes'),
      status: _requiredStatus(json, 'status', const {'confirmed'}),
      syncStatus: _requiredStatus(json, 'syncStatus', const {
        'pending',
        'synced',
        'failed',
      }),
    );
  }
}

class DashboardClient {
  const DashboardClient({required this.name});

  final String name;

  factory DashboardClient.fromJson(Map<String, dynamic> json) {
    return DashboardClient(name: _requiredNonEmptyString(json, 'name'));
  }
}

int _requiredCount(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value >= 0) return value;
  throw FormatException('El campo "$key" no tiene un contador válido.');
}

int _requiredPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int && value > 0) return value;
  throw FormatException('El campo "$key" no tiene un entero válido.');
}

String _requiredNonEmptyString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('El campo "$key" no tiene un texto válido.');
}

String _requiredStatus(
  Map<String, dynamic> json,
  String key,
  Set<String> allowed,
) {
  final value = json[key];
  if (value is String && allowed.contains(value)) return value;
  throw FormatException('El estado "$key" no es válido.');
}

DateTime _requiredIsoDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  final isIsoTimestamp =
      value is String &&
      RegExp(
        r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
      ).hasMatch(value);
  if (!isIsoTimestamp) {
    throw FormatException('El campo "$key" no tiene una fecha ISO válida.');
  }

  try {
    return DateTime.parse(value);
  } on FormatException {
    throw FormatException('El campo "$key" no tiene una fecha ISO válida.');
  }
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El campo "$key" no tiene un objeto válido.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('El campo "$key" no tiene una lista válida.');
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El elemento "$field" no tiene un objeto válido.');
}
