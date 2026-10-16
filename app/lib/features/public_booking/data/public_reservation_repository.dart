import '../../../core/network/api_client.dart';
import '../domain/public_availability.dart';
import '../domain/public_appointment.dart';
import '../domain/public_confirmation.dart';
import '../domain/public_reservation.dart';

class PublicReservationRepository {
  PublicReservationRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<PublicReservation> getReservation(String token) async {
    _validateToken(token);
    final response = await _apiClient.getJson(
      '/public/reservations/${_segment(token)}',
    );
    return PublicReservation.fromJson(response);
  }

  Future<PublicAvailability> getAvailability(
    String token, {
    required DateTime from,
    required DateTime to,
  }) async {
    _validateToken(token);
    final fromDate = _dateOnly(from);
    final toDate = _dateOnly(to);
    if (fromDate.compareTo(toDate) > 0) {
      throw const FormatException('El rango de disponibilidad no es válido.');
    }
    final path = Uri(
      path: '/public/reservations/${_segment(token)}/availability',
      queryParameters: <String, String>{'from': fromDate, 'to': toDate},
    ).toString();
    final response = await _apiClient.getJson(path);
    return PublicAvailability.fromJson(response);
  }

  Future<PublicConfirmation> confirmReservation(
    String token,
    DateTime startAt, {
    required String idempotencyKey,
  }) async {
    _validateToken(token);
    if (!startAt.isUtc) {
      throw const FormatException('El horario debe ser un instante UTC.');
    }
    if (idempotencyKey.trim().isEmpty || idempotencyKey.length > 128) {
      throw const FormatException('La clave de confirmación no es válida.');
    }
    final response = await _apiClient.postJson(
      '/public/reservations/${_segment(token)}/confirm',
      body: <String, dynamic>{'startAt': startAt.toUtc().toIso8601String()},
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
    );
    return PublicConfirmation.fromJson(response);
  }

  Future<PublicAppointment> getAppointment(String token) async {
    _validateToken(token);
    final response = await _apiClient.getJson(
      '/public/reservations/${_segment(token)}/appointment',
    );
    return PublicAppointment.fromJson(response);
  }

  void _validateToken(String token) {
    if (token.trim().isEmpty) {
      throw const FormatException('El enlace público no es válido.');
    }
  }

  String _segment(String value) => Uri.encodeComponent(value);

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
