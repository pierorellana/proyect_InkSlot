import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';

void main() {
  test('encodes public token and date-only availability query', () async {
    final api = RecordingApiClient(<String, dynamic>{
      'timezone': 'America/Guayaquil',
      'days': <dynamic>[],
    });
    final repository = PublicReservationRepository(api);

    await repository.getAvailability(
      'token/with spaces',
      from: DateTime(2026, 10, 23, 23),
      to: DateTime(2026, 10, 24, 1),
    );

    expect(
      api.path,
      '/public/reservations/token%2Fwith%20spaces/availability?from=2026-10-23&to=2026-10-24',
    );
  });

  test('maps a public summary response strictly', () async {
    final api = RecordingApiClient(<String, dynamic>{
      'status': 'booked',
      'artist': <String, dynamic>{'displayName': 'Gio Ink'},
      'durationMinutes': 60,
      'timezone': 'UTC',
      'restrictions': <String, dynamic>{
        'minDate': null,
        'maxDate': null,
        'allowedWeekdays': null,
        'allowedWindows': null,
      },
      'expiresAt': '2026-10-17T12:00:00.000Z',
    });

    final reservation = await PublicReservationRepository(
      api,
    ).getReservation('safe-token');

    expect(reservation.isBooked, isTrue);
    expect(api.path, '/public/reservations/safe-token');
  });

  test(
    'confirms a reservation with UTC payload and idempotency header',
    () async {
      final api = RecordingApiClient(<String, dynamic>{
        'status': 'confirmed',
        'syncStatus': 'pending',
        'startAt': '2026-10-20T15:00:00.000Z',
        'endAt': '2026-10-20T18:00:00.000Z',
        'timezone': 'America/Guayaquil',
      });

      final confirmation = await PublicReservationRepository(api)
          .confirmReservation(
            'safe-token',
            DateTime.utc(2026, 10, 20, 15),
            idempotencyKey: 'key-in-memory',
          );

      expect(confirmation.syncStatus, 'pending');
      expect(api.path, '/public/reservations/safe-token/confirm');
      expect(api.body, <String, dynamic>{
        'startAt': '2026-10-20T15:00:00.000Z',
      });
      expect(api.headers, <String, String>{'Idempotency-Key': 'key-in-memory'});
    },
  );

  test('loads the safe appointment lookup response', () async {
    final api = RecordingApiClient(<String, dynamic>{
      'status': 'confirmed',
      'syncStatus': 'synced',
      'startAt': '2026-10-20T15:00:00.000Z',
      'endAt': '2026-10-20T18:00:00.000Z',
      'timezone': 'America/Guayaquil',
    });

    final appointment = await PublicReservationRepository(
      api,
    ).getAppointment('token/with spaces');

    expect(appointment.status, 'confirmed');
    expect(api.path, '/public/reservations/token%2Fwith%20spaces/appointment');
  });
}

class RecordingApiClient implements ApiClient {
  RecordingApiClient(this.response);

  final Map<String, dynamic> response;
  String? path;
  Map<String, dynamic>? body;
  Map<String, String>? headers;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    this.path = path;
    return response;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    this.body = body;
    this.headers = headers;
    this.path = path;
    return response;
  }
}
