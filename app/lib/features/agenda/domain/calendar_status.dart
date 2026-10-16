enum CalendarConnectionState {
  connected,
  disconnected,
  error,
  needsReconnect;

  static CalendarConnectionState fromApi(Object? value) {
    if (value is! String) {
      throw const FormatException('El estado del calendario no es válido.');
    }
    return switch (value) {
      'connected' => CalendarConnectionState.connected,
      'disconnected' => CalendarConnectionState.disconnected,
      'error' => CalendarConnectionState.error,
      'needs_reconnect' => CalendarConnectionState.needsReconnect,
      _ => throw FormatException(
        'El API devolvió un estado de calendario desconocido: $value.',
      ),
    };
  }
}

class CalendarStatus {
  const CalendarStatus({required this.state, this.calendarName});

  final CalendarConnectionState state;
  final String? calendarName;

  factory CalendarStatus.fromJson(Map<String, dynamic> json) {
    final name = json['calendarName'];
    if (name != null && name is! String) {
      throw const FormatException('El nombre del calendario no es válido.');
    }
    return CalendarStatus(
      state: CalendarConnectionState.fromApi(json['status']),
      calendarName: name as String?,
    );
  }
}

class CalendarAuthorization {
  const CalendarAuthorization({required this.url, required this.expiresAt});

  final String url;
  final DateTime expiresAt;

  factory CalendarAuthorization.fromJson(Map<String, dynamic> json) {
    final url = json['authorizationUrl'];
    final expiresAt = json['expiresAt'];
    if (url is! String || url.isEmpty || expiresAt is! String) {
      throw const FormatException('La autorización de Google no es válida.');
    }
    final parsed = DateTime.tryParse(expiresAt);
    if (parsed == null) {
      throw const FormatException(
        'La vigencia de la autorización no es válida.',
      );
    }
    return CalendarAuthorization(url: url, expiresAt: parsed);
  }
}
