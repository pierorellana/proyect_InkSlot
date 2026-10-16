import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';

void main() {
  test(
    'loads active summary and availability, then stores selection locally',
    () async {
      final day = DateTime(2026, 10, 23);
      final slot = AvailabilitySlot(
        startAt: DateTime.utc(2026, 10, 23, 15),
        endAt: DateTime.utc(2026, 10, 23, 18),
      );
      final controller = PublicReservationController(
        FakePublicRepository(
          reservation: _reservation(),
          availability: PublicAvailability(
            timezone: 'America/Guayaquil',
            days: <AvailabilityDay>[
              AvailabilityDay(date: day, slots: <AvailabilitySlot>[slot]),
            ],
          ),
        ),
      );

      await controller.loadReservation('safe-token');
      await controller.loadAvailability('safe-token', day, day);
      controller.selectDate(day);
      controller.selectSlot(slot);

      expect(controller.reservationStatus, PublicReservationStatus.active);
      expect(controller.availabilityStatus, PublicAvailabilityStatus.ready);
      expect(controller.selectedDay!.date, day);
      expect(controller.selectedSlot, same(slot));
    },
  );

  test('maps calendar failure separately from offline failure', () async {
    final calendar = PublicReservationController(
      FakePublicRepository(
        error: const ApiException(
          code: 'CALENDAR_UNAVAILABLE',
          message: 'Agenda no verificable',
          statusCode: 503,
        ),
      ),
    );
    await calendar.loadAvailability(
      'safe-token',
      DateTime(2026, 10, 23),
      DateTime(2026, 10, 23),
    );
    expect(
      calendar.availabilityStatus,
      PublicAvailabilityStatus.calendarUnavailable,
    );

    final offline = PublicReservationController(
      FakePublicRepository(
        error: const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Sin conexión',
        ),
      ),
    );
    await offline.loadAvailability(
      'safe-token',
      DateTime(2026, 10, 23),
      DateTime(2026, 10, 23),
    );
    expect(offline.availabilityStatus, PublicAvailabilityStatus.offline);
  });

  test(
    'clears stale selection when a new availability response arrives',
    () async {
      final repository = FakePublicRepository(
        reservation: _reservation(),
        availability: const PublicAvailability(timezone: 'UTC', days: []),
      );
      final controller = PublicReservationController(repository);
      final day = DateTime(2026, 10, 23);
      final slot = AvailabilitySlot(
        startAt: DateTime.utc(2026, 10, 23, 15),
        endAt: DateTime.utc(2026, 10, 23, 16),
      );
      repository.availability = PublicAvailability(
        timezone: 'UTC',
        days: <AvailabilityDay>[
          AvailabilityDay(date: day, slots: <AvailabilitySlot>[slot]),
        ],
      );
      await controller.loadAvailability('safe-token', day, day);
      controller.selectSlot(slot);
      repository.availability = const PublicAvailability(
        timezone: 'UTC',
        days: [],
      );
      await controller.loadAvailability('safe-token', day, day);
      expect(controller.selectedSlot, isNull);
      expect(controller.availabilityStatus, PublicAvailabilityStatus.empty);
    },
  );
}

PublicReservation _reservation() => PublicReservation(
  status: 'pending',
  artistDisplayName: 'Gio Ink',
  durationMinutes: 180,
  timezone: 'America/Guayaquil',
  restrictions: const PublicRestrictions(
    minDate: null,
    maxDate: null,
    allowedWeekdays: null,
    allowedWindows: null,
  ),
  expiresAt: DateTime.utc(2026, 11, 30),
);

class FakePublicRepository extends PublicReservationRepository {
  FakePublicRepository({this.reservation, this.availability, this.error})
    : super(_NoopApiClient());

  PublicReservation? reservation;
  PublicAvailability? availability;
  Object? error;

  @override
  Future<PublicReservation> getReservation(String token) async {
    if (error != null) throw error!;
    return reservation!;
  }

  @override
  Future<PublicAvailability> getAvailability(
    String token, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (error != null) throw error!;
    return availability!;
  }
}

class _NoopApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => <String, dynamic>{};
}
