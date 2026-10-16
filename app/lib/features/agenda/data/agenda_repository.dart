import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/availability.dart';
import '../domain/calendar_status.dart';

class AgendaRepository {
  AgendaRepository(this._apiClient);

  final ApiClient _apiClient;

  RestApiClient get _rest {
    final client = _apiClient;
    if (client is RestApiClient) return client;
    throw const ApiException(
      code: 'UNAVAILABLE',
      message: 'No hay una sesión administrativa disponible.',
    );
  }

  Future<CalendarStatus> calendarStatus() async => CalendarStatus.fromJson(
    await _apiClient.getJson('/admin/calendar/status'),
  );

  Future<CalendarAuthorization> connectCalendar() async =>
      CalendarAuthorization.fromJson(
        await _apiClient.getJson('/admin/calendar/connect'),
      );

  Future<CalendarAuthorization> reconnectCalendar() async =>
      CalendarAuthorization.fromJson(
        await _apiClient.postJson('/admin/calendar/reconnect'),
      );

  Future<void> disconnectCalendar() async {
    await _apiClient.postJson('/admin/calendar/disconnect');
  }

  /// Devuelve `null` cuando el estudio aún no configuró su disponibilidad.
  Future<AdminAvailability?> availability() async {
    try {
      return AdminAvailability.fromJson(
        await _apiClient.getJson('/admin/availability'),
      );
    } on ApiException catch (error) {
      if (error.code == 'AVAILABILITY_NOT_CONFIGURED') return null;
      rethrow;
    }
  }

  Future<AdminAvailability> updateAvailability(
    AdminAvailability availability,
  ) async => AdminAvailability.fromJson(
    await _rest.putJson('/admin/availability', body: availability.toJson()),
  );

  Future<List<AvailabilityBlock>> blocks() async {
    final items = await _rest.getJsonList('/admin/blocks');
    return items
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Un bloqueo no es válido.');
          }
          return AvailabilityBlock.fromJson(Map<String, dynamic>.from(item));
        })
        .toList(growable: false);
  }

  Future<AvailabilityBlock> createBlock({
    required DateTime startAt,
    required DateTime endAt,
    String? reason,
  }) async => AvailabilityBlock.fromJson(
    await _apiClient.postJson(
      '/admin/blocks',
      body: <String, dynamic>{
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    ),
  );

  Future<void> deleteBlock(String id) =>
      _rest.deleteJson('/admin/blocks/${Uri.encodeComponent(id)}');
}
