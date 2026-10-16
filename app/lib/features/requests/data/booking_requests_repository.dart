import '../../../core/network/api_client.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';

class BookingRequestsRepository {
  BookingRequestsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<BookingRequestPage> list({
    BookingRequestStatus? status,
    String? cursor,
  }) async {
    final query = <String, String>{
      if (status != null) 'status': status.apiValue,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };
    final path = Uri(
      path: '/admin/booking-requests',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    return BookingRequestPage.fromJson(await _apiClient.getJson(path));
  }

  Future<BookingRequestDetail> detail(String id) async {
    return BookingRequestDetail.fromJson(
      await _apiClient.getJson('/admin/booking-requests/${_segment(id)}'),
    );
  }

  Future<BookingRequestActionResult> create(
    CreateBookingRequestInput input,
  ) async {
    final response = await _apiClient.postJson(
      '/admin/booking-requests',
      body: _createBody(input),
    );
    return _parseActionResult(response);
  }

  Future<BookingRequestActionResult> renew(
    String id, {
    int? tokenTtlHours,
  }) async {
    final response = await _apiClient.postJson(
      '/admin/booking-requests/${_segment(id)}/renew',
      body: <String, dynamic>{
        ...?(tokenTtlHours == null
            ? null
            : <String, dynamic>{'tokenTtlHours': tokenTtlHours}),
      },
    );
    return _parseActionResult(response);
  }

  Future<BookingRequest> revoke(String id) async {
    return BookingRequest.fromJson(
      await _apiClient.postJson(
        '/admin/booking-requests/${_segment(id)}/revoke',
      ),
    );
  }

  Future<BookingRequest> close(String id) async {
    return BookingRequest.fromJson(
      await _apiClient.postJson(
        '/admin/booking-requests/${_segment(id)}/close',
      ),
    );
  }

  Map<String, dynamic> _createBody(CreateBookingRequestInput input) {
    final body = <String, dynamic>{
      'client': <String, dynamic>{'name': input.clientName.trim()},
      'depositVerified': input.depositVerified,
      'durationMinutes': input.durationMinutes,
    };

    final channel = input.contactChannel;
    final contactValue = input.contactValue;
    if ((channel == null) != (contactValue == null)) {
      throw const FormatException(
        'El canal y el valor de contacto deben enviarse juntos.',
      );
    }
    if (channel != null && contactValue != null) {
      body['contactChannel'] = channel.apiValue;
      body['contactValue'] = contactValue.trim();
    }
    if (input.paymentReference != null) {
      body['paymentReference'] = input.paymentReference!.trim();
    }
    if (input.preferredDate != null) {
      final date = _dateOnly(input.preferredDate!);
      body['minDate'] = date;
      body['maxDate'] = date;
    }
    if (input.preferredTimeRange != null) {
      body['allowedWindows'] = <Map<String, String>>[
        _parseTimeRange(input.preferredTimeRange!),
      ];
    }
    if (input.preferredDays.isNotEmpty) {
      body['allowedWeekdays'] = input.preferredDays
          .map(_weekdayValue)
          .toList(growable: false);
    }
    if (input.tokenTtlHours != null) {
      body['tokenTtlHours'] = input.tokenTtlHours;
    }
    return body;
  }

  BookingRequestActionResult _parseActionResult(Map<String, dynamic> response) {
    final request = response['request'];
    final link = response['link'];
    if (request is! Map || link is! Map) {
      throw const FormatException(
        'El servidor devolvió una respuesta de enlace inválida.',
      );
    }
    return BookingRequestActionResult(
      request: BookingRequest.fromJson(Map<String, dynamic>.from(request)),
      link: LinkReadyData.fromJson(Map<String, dynamic>.from(link)),
    );
  }

  String _segment(String value) => Uri.encodeComponent(value);

  String _dateOnly(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  Map<String, String> _parseTimeRange(String value) {
    final match = RegExp(
      r'^\s*([01]\d|2[0-3]):([0-5]\d)\s*[-–]\s*([01]\d|2[0-3]):([0-5]\d)\s*$',
    ).firstMatch(value);
    if (match == null) {
      throw const FormatException('La franja horaria no es válida.');
    }
    return <String, String>{
      'startLocal': '${match.group(1)}:${match.group(2)}',
      'endLocal': '${match.group(3)}:${match.group(4)}',
    };
  }

  int _weekdayValue(String value) {
    final normalized = value.trim().toLowerCase();
    const weekdays = <String, int>{
      'domingo': 0,
      'sunday': 0,
      'dom': 0,
      'lunes': 1,
      'monday': 1,
      'lun': 1,
      'martes': 2,
      'tuesday': 2,
      'mar': 2,
      'miércoles': 3,
      'miercoles': 3,
      'wednesday': 3,
      'mié': 3,
      'mie': 3,
      'jueves': 4,
      'thursday': 4,
      'jue': 4,
      'viernes': 5,
      'friday': 5,
      'vie': 5,
      'sábado': 6,
      'sabado': 6,
      'saturday': 6,
      'sáb': 6,
      'sab': 6,
    };
    final result = weekdays[normalized];
    if (result == null) {
      throw FormatException('El día preferido no es válido: $value.');
    }
    return result;
  }
}
