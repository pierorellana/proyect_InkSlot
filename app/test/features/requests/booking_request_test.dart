import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';

void main() {
  test('parses an administrative request with nullable contact data', () {
    final request = BookingRequest.fromJson(_requestJson());

    expect(request.status, BookingRequestStatus.pending);
    expect(request.client.contactChannel, ContactChannel.instagram);
    expect(request.client.contactValue, '@ink.client');
    expect(request.client.email, isNull);
    expect(request.paymentReference, 'transfer-123');
    expect(request.minDate, DateTime.utc(2026, 10, 20));
    expect(request.createdAt.isUtc, isTrue);
  });

  test('accepts absent nullable fields and keeps nulls strict', () {
    final json = _requestJson()
      ..remove('paymentReference')
      ..remove('minDate')
      ..remove('maxDate')
      ..remove('allowedWeekdays')
      ..remove('allowedWindows');
    final client = (json['client'] as Map<String, dynamic>)
      ..remove('email')
      ..remove('phone')
      ..remove('contactChannel')
      ..remove('contactValue');

    final request = BookingRequest.fromJson(json);

    expect(request.paymentReference, isNull);
    expect(request.allowedWindows, isNull);
    expect(request.client.contactChannel, isNull);
    expect(request.client.contactValue, isNull);
    expect(client, isNotEmpty);
  });

  test('rejects unknown status and malformed required fields', () {
    final unknownStatus = _requestJson()..['status'] = 'queued';
    expect(
      () => BookingRequest.fromJson(unknownStatus),
      throwsA(isA<FormatException>()),
    );

    final malformedDuration = _requestJson()..['durationMinutes'] = '120';
    expect(
      () => BookingRequest.fromJson(malformedDuration),
      throwsA(isA<FormatException>()),
    );
  });

  test('parses paginated response and detail metadata', () {
    final request = _requestJson();
    final page = BookingRequestPage.fromJson({
      'items': [request],
      'nextCursor': 'opaque-cursor',
    });
    final detail = BookingRequestDetail.fromJson({
      'request': request,
      'currentLink': {'status': 'active', 'expiresAt': '2026-10-21T12:00:00Z'},
      'audit': [
        {'action': 'created', 'createdAt': '2026-10-16T10:00:00Z'},
      ],
    });

    expect(page.items, hasLength(1));
    expect(page.nextCursor, 'opaque-cursor');
    expect(detail.currentLink?.status, BookingLinkStatus.active);
    expect(detail.audit.single.action, 'created');
  });
}

Map<String, dynamic> _requestJson() => {
  'id': 'request-1',
  'client': {
    'id': 'client-1',
    'name': 'Ana Ink',
    'email': null,
    'phone': null,
    'contactChannel': 'instagram',
    'contactValue': '@ink.client',
  },
  'paymentReference': 'transfer-123',
  'depositVerified': true,
  'durationMinutes': 120,
  'status': 'pending',
  'minDate': '2026-10-20',
  'maxDate': null,
  'allowedWeekdays': [1, 2],
  'allowedWindows': [
    {'startLocal': '10:00', 'endLocal': '13:00'},
  ],
  'createdAt': '2026-10-16T10:00:00-05:00',
};
