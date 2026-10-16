import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../agenda/domain/availability.dart';
import '../../sync_issues/domain/sync_issue.dart';
import '../domain/admin_appointment.dart';

class AdminAppointmentsRepository {
  AdminAppointmentsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminAppointmentPage> list({
    AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
    String? cursor,
  }) async {
    final query = <String, String>{
      'status': status.apiValue,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final path = Uri(
      path: '/admin/appointments',
      queryParameters: query,
    ).toString();
    return AdminAppointmentPage.fromJson(await _apiClient.getJson(path));
  }

  Future<AdminAppointmentDetail> detail(String id) async =>
      AdminAppointmentDetail.fromJson(await _apiClient.getJson(_path(id)));

  Future<AdminAppointmentDetail> reschedule(
    String id, {
    required DateTime startAt,
    required int version,
  }) async => AdminAppointmentDetail.fromJson(
    await _rest.patchJson(
      '${_path(id)}/reschedule',
      body: <String, dynamic>{
        'startAt': startAt.toUtc().toIso8601String(),
        'version': version,
      },
    ),
  );

  Future<AdminAppointmentDetail> cancel(String id, {required int version}) =>
      _action(id, 'cancel', version);

  Future<AdminAppointmentDetail> complete(String id, {required int version}) =>
      _action(id, 'complete', version);

  Future<AdminAppointmentDetail> noShow(String id, {required int version}) =>
      _action(id, 'no-show', version);

  /// Reintenta la incidencia abierta de la cita; no hace nada si no hay.
  Future<void> retrySync(String id) async {
    final issues = SyncIssueList.fromJson(
      await _apiClient.getJson('/admin/sync-issues?status=open'),
    );
    for (final issue in issues.items) {
      if (issue.appointmentId == id) {
        await _apiClient.postJson(
          '/admin/sync-issues/${Uri.encodeComponent(issue.id)}/retry',
        );
      }
    }
  }

  /// Ventanas semanales del estudio para proponer horarios al reprogramar.
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

  Future<AdminAppointmentDetail> _action(
    String id,
    String action,
    int version,
  ) async => AdminAppointmentDetail.fromJson(
    await _apiClient.postJson(
      '${_path(id)}/$action',
      body: <String, dynamic>{'version': version},
    ),
  );

  String _path(String id) => '/admin/appointments/${Uri.encodeComponent(id)}';

  RestApiClient get _rest {
    final client = _apiClient;
    if (client is RestApiClient) return client;
    throw const ApiException(
      code: 'UNAVAILABLE',
      message: 'No hay una sesión administrativa disponible.',
    );
  }
}
