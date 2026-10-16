import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';

void main() {
  test(
    'maps status and cursor filters to the administrative list endpoint',
    () async {
      final api = RecordingApiClient(
        getResult: <String, dynamic>{'items': <dynamic>[], 'nextCursor': null},
      );
      final repository = BookingRequestsRepository(api);

      final page = await repository.list(
        status: BookingRequestStatus.expired,
        cursor: 'opaque/cursor',
      );

      expect(page.items, isEmpty);
      expect(
        api.lastGetPath,
        '/admin/booking-requests?status=expired&cursor=opaque%2Fcursor',
      );
    },
  );

  test('maps create input to the current API contract', () async {
    final api = RecordingApiClient(getResult: _response());
    final repository = BookingRequestsRepository(api);

    await repository.create(
      CreateBookingRequestInput(
        clientName: ' Ana Ink ',
        contactChannel: ContactChannel.whatsapp,
        contactValue: ' +593 999 ',
        paymentReference: ' transfer-1 ',
        depositVerified: true,
        durationMinutes: 120,
        restrictionNotes: 'private note is not sent',
        preferredDate: DateTime.utc(2026, 10, 20),
        preferredTimeRange: '10:00–13:00',
        preferredDays: const ['lunes', 'miércoles'],
        tokenTtlHours: 48,
      ),
    );

    expect(api.lastPostPath, '/admin/booking-requests');
    expect(api.lastPostBody, {
      'client': {'name': 'Ana Ink'},
      'depositVerified': true,
      'durationMinutes': 120,
      'contactChannel': 'whatsapp',
      'contactValue': '+593 999',
      'paymentReference': 'transfer-1',
      'minDate': '2026-10-20',
      'maxDate': '2026-10-20',
      'allowedWindows': [
        {'startLocal': '10:00', 'endLocal': '13:00'},
      ],
      'allowedWeekdays': [1, 3],
      'tokenTtlHours': 48,
    });
  });

  test('maps renew, revoke, and close lifecycle endpoints', () async {
    final api = RecordingApiClient(
      getResult: _response(),
      postResults: <String, Map<String, dynamic>>{
        '/admin/booking-requests/request%2F1/renew': _response(),
        '/admin/booking-requests/request%2F1/revoke': _requestOnly(),
        '/admin/booking-requests/request%2F1/close': _requestOnly(),
      },
    );
    final repository = BookingRequestsRepository(api);

    await repository.renew('request/1', tokenTtlHours: 24);
    expect(api.lastPostPath, '/admin/booking-requests/request%2F1/renew');
    expect(api.lastPostBody, {'tokenTtlHours': 24});

    await repository.revoke('request/1');
    expect(api.lastPostPath, '/admin/booking-requests/request%2F1/revoke');
    expect(api.lastPostBody, isNull);

    await repository.close('request/1');
    expect(api.lastPostPath, '/admin/booking-requests/request%2F1/close');
  });
}

class RecordingApiClient implements ApiClient {
  RecordingApiClient({
    required this.getResult,
    this.postResult,
    this.postResults,
  });

  final Map<String, dynamic> getResult;
  final Map<String, dynamic>? postResult;
  final Map<String, Map<String, dynamic>>? postResults;
  String? lastGetPath;
  String? lastPostPath;
  Map<String, dynamic>? lastPostBody;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    lastGetPath = path;
    return getResult;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    return postResults?[path] ?? postResult ?? _response();
  }
}

Map<String, dynamic> _response() => {
  'request': {
    'id': 'request-1',
    'client': {
      'id': 'client-1',
      'name': 'Ana Ink',
      'email': null,
      'phone': '+593 999',
      'contactChannel': 'whatsapp',
      'contactValue': '+593 999',
    },
    'paymentReference': 'transfer-1',
    'depositVerified': true,
    'durationMinutes': 120,
    'status': 'pending',
    'minDate': null,
    'maxDate': null,
    'allowedWeekdays': null,
    'allowedWindows': null,
    'createdAt': '2026-10-16T10:00:00Z',
  },
  'link': {'path': '/r/raw-token', 'expiresAt': '2026-10-18T10:00:00Z'},
};

Map<String, dynamic> _requestOnly() =>
    Map<String, dynamic>.from(_response()['request'] as Map);
