import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_appointment.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_confirmation.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';

void main() {
  test(
    'reuses the in-memory idempotency key after a network failure',
    () async {
      final slot = _slot(15);
      final repository = _ConfirmationRepository(
        availability: _availability(slot),
        confirmationError: const ApiException(
          code: 'NETWORK_ERROR',
          message: 'Sin conexión',
        ),
      );
      final controller = PublicReservationController(repository);
      await controller.loadAvailability('safe-token', _date, _date);
      controller.selectSlot(slot);

      await controller.confirmSelected('safe-token');
      expect(controller.confirmationStatus, PublicConfirmationStatus.offline);

      repository.confirmationError = null;
      await controller.confirmSelected('safe-token');

      expect(controller.confirmationStatus, PublicConfirmationStatus.confirmed);
      expect(repository.idempotencyKeys, hasLength(2));
      expect(repository.idempotencyKeys[0], repository.idempotencyKeys[1]);
      expect(controller.selectedSlot, isNull);
    },
  );

  test('maps conflicts and generates a new key after changing slot', () async {
    final firstSlot = _slot(15);
    final secondSlot = _slot(16);
    final repository = _ConfirmationRepository(
      availability: _availability(firstSlot, secondSlot),
      confirmationError: const ApiException(
        statusCode: 409,
        code: 'SLOT_UNAVAILABLE',
        message: 'Horario no disponible',
      ),
    );
    final controller = PublicReservationController(repository);
    await controller.loadAvailability('safe-token', _date, _date);
    controller.selectSlot(firstSlot);
    await controller.confirmSelected('safe-token');
    expect(controller.confirmationStatus, PublicConfirmationStatus.conflict);

    controller.selectSlot(secondSlot);
    await controller.confirmSelected('safe-token');

    expect(repository.idempotencyKeys[0], isNot(repository.idempotencyKeys[1]));
    expect(controller.confirmationStatus, PublicConfirmationStatus.conflict);
  });

  test('loads a public appointment for a result deep link', () async {
    final repository = _ConfirmationRepository(appointment: _appointment());
    final controller = PublicReservationController(repository);

    final appointment = await controller.loadAppointment('consumed-token');

    expect(appointment, isNotNull);
    expect(controller.confirmationStatus, PublicConfirmationStatus.confirmed);
    expect(controller.appointment!.syncStatus, 'pending');
  });
}

final _date = DateTime(2026, 10, 20);

AvailabilitySlot _slot(int hour) => AvailabilitySlot(
  startAt: DateTime.utc(2026, 10, 20, hour),
  endAt: DateTime.utc(2026, 10, 20, hour + 1),
);

PublicAvailability _availability(
  AvailabilitySlot first, [
  AvailabilitySlot? second,
]) => PublicAvailability(
  timezone: 'America/Guayaquil',
  days: <AvailabilityDay>[
    AvailabilityDay(
      date: _date,
      slots: <AvailabilitySlot>[first, if (second != null) second],
    ),
  ],
);

PublicAppointment _appointment() => PublicAppointment(
  status: 'confirmed',
  syncStatus: 'pending',
  startAt: DateTime.utc(2026, 10, 20, 15),
  endAt: DateTime.utc(2026, 10, 20, 18),
  timezone: 'America/Guayaquil',
);

class _ConfirmationRepository extends PublicReservationRepository {
  _ConfirmationRepository({
    this.availability,
    this.confirmationError,
    this.appointment,
  }) : super(_NoopApiClient());

  final PublicAvailability? availability;
  Object? confirmationError;
  final PublicAppointment? appointment;
  final List<String> idempotencyKeys = <String>[];

  @override
  Future<PublicAvailability> getAvailability(
    String token, {
    required DateTime from,
    required DateTime to,
  }) async => availability!;

  @override
  Future<PublicConfirmation> confirmReservation(
    String token,
    DateTime startAt, {
    required String idempotencyKey,
  }) async {
    idempotencyKeys.add(idempotencyKey);
    if (confirmationError != null) throw confirmationError!;
    return PublicConfirmation(
      status: 'confirmed',
      syncStatus: 'pending',
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 1)),
      timezone: 'America/Guayaquil',
    );
  }

  @override
  Future<PublicAppointment> getAppointment(String token) async {
    if (appointment == null) {
      throw const ApiException(
        statusCode: 404,
        code: 'APPOINTMENT_NOT_FOUND',
        message: 'No se encontró la reserva.',
      );
    }
    return appointment!;
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
