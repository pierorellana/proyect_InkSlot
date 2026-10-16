enum SyncIssueStatus {
  open,
  resolved;

  static SyncIssueStatus fromApi(Object? value) {
    if (value is! String) {
      throw const FormatException('El estado de la incidencia no es válido.');
    }
    return switch (value) {
      'open' => SyncIssueStatus.open,
      'resolved' => SyncIssueStatus.resolved,
      _ => throw FormatException(
        'El API devolvió un estado de incidencia desconocido: $value.',
      ),
    };
  }

  String get apiValue => name;
}

class SyncIssue {
  const SyncIssue({
    required this.id,
    required this.appointmentId,
    required this.operation,
    required this.code,
    required this.message,
    required this.status,
    required this.lastAttemptAt,
    required this.createdAt,
  });

  final String id;
  final String appointmentId;
  final String operation;
  final String code;
  final String message;
  final SyncIssueStatus status;
  final DateTime? lastAttemptAt;
  final DateTime createdAt;

  factory SyncIssue.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final appointmentId = json['appointmentId'];
    final operation = json['operation'];
    final code = json['code'];
    final message = json['message'];
    final createdAt = json['createdAt'];
    if ([
      id,
      appointmentId,
      operation,
      code,
      message,
      createdAt,
    ].any((value) => value is! String)) {
      throw const FormatException('La incidencia tiene datos inválidos.');
    }

    final lastAttemptAt = json['lastAttemptAt'];
    if (lastAttemptAt != null && lastAttemptAt is! String) {
      throw const FormatException('La fecha del intento no es válida.');
    }

    final parsedCreatedAt = DateTime.tryParse(createdAt);
    if (parsedCreatedAt == null) {
      throw const FormatException('La fecha de creación no es válida.');
    }
    final parsedLastAttemptAt = lastAttemptAt == null
        ? null
        : DateTime.tryParse(lastAttemptAt);
    if (lastAttemptAt != null && parsedLastAttemptAt == null) {
      throw const FormatException('La fecha del intento no es válida.');
    }

    return SyncIssue(
      id: id,
      appointmentId: appointmentId,
      operation: operation,
      code: code,
      message: message,
      status: SyncIssueStatus.fromApi(json['status']),
      lastAttemptAt: parsedLastAttemptAt,
      createdAt: parsedCreatedAt,
    );
  }
}

class SyncIssueList {
  const SyncIssueList({required this.items});

  final List<SyncIssue> items;

  factory SyncIssueList.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('La lista de incidencias no es válida.');
    }
    return SyncIssueList(
      items: rawItems
          .map((item) {
            if (item is! Map) {
              throw const FormatException('La incidencia no es válida.');
            }
            return SyncIssue.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
    );
  }
}
