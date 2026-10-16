import '../../../core/network/api_client.dart';
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
}
