import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_appointment.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_confirmation.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';

/// Días con horarios libres de octubre del prototipo.
const openOctoberDays = [16, 17, 20, 21, 22, 23, 24, 27, 28, 31];

class ShotRepository extends PublicReservationRepository {
  ShotRepository({
    this.reservationError,
    this.availabilityError,
    this.confirmError,
    this.emptyAvailability = false,
    this.syncStatus = 'synced',
    this.availabilityDelay,
    this.confirmDelay,
  }) : super(_Noop());

  Object? reservationError;
  Object? availabilityError;
  Object? confirmError;
  final bool emptyAvailability;
  final String syncStatus;
  Duration? availabilityDelay;
  final Duration? confirmDelay;

  @override
  Future<PublicReservation> getReservation(String token) async {
    if (reservationError != null) throw reservationError!;
    return PublicReservation(
      status: 'pending',
      artistDisplayName: 'Valentina',
      durationMinutes: 180,
      timezone: 'America/Guayaquil',
      restrictions: const PublicRestrictions(
        minDate: null,
        maxDate: null,
        allowedWeekdays: [2, 3, 4, 5, 6],
        allowedWindows: null,
      ),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 47)),
    );
  }

  @override
  Future<PublicAvailability> getAvailability(
    String token, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (availabilityDelay != null) {
      await Future<void>.delayed(availabilityDelay!);
    }
    if (availabilityError != null) throw availabilityError!;
    if (emptyAvailability) {
      return const PublicAvailability(timezone: 'America/Guayaquil', days: []);
    }
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, 1);
    return PublicAvailability(
      timezone: 'America/Guayaquil',
      days: [
        for (final d in openOctoberDays)
          if (!DateTime(base.year, base.month, d).isBefore(from) &&
              !DateTime(base.year, base.month, d).isAfter(to))
            AvailabilityDay(
              date: DateTime(base.year, base.month, d),
              slots: [
                for (final m in [630, 750, 870, 900, 930, 960, 990, 1020])
                  slot(base.year, base.month, d, m),
              ],
            ),
      ],
    );
  }

  AvailabilitySlot slot(int year, int month, int day, int minutes) {
    final start = DateTime.utc(year, month, day, minutes ~/ 60 + 5, minutes % 60);
    return AvailabilitySlot(
      startAt: start,
      endAt: start.add(const Duration(hours: 3)),
    );
  }

  @override
  Future<PublicConfirmation> confirmReservation(
    String token,
    DateTime startAt, {
    required String idempotencyKey,
  }) async {
    if (confirmDelay != null) await Future<void>.delayed(confirmDelay!);
    if (confirmError != null) throw confirmError!;
    return PublicConfirmation(
      status: 'confirmed',
      syncStatus: syncStatus,
      startAt: startAt,
      endAt: startAt.add(const Duration(hours: 3)),
      timezone: 'America/Guayaquil',
    );
  }

  @override
  Future<PublicAppointment> getAppointment(String token) async =>
      PublicAppointment(
        status: 'confirmed',
        syncStatus: syncStatus,
        startAt: DateTime.utc(2026, 10, 24, 19, 30),
        endAt: DateTime.utc(2026, 10, 24, 22, 30),
        timezone: 'America/Guayaquil',
      );
}

ApiException apiError(String code, {int? status}) =>
    ApiException(statusCode: status, code: code, message: code);

class _Noop implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async => {};
  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => {};
}

PublicReservationController shotController(ShotRepository repo) =>
    PublicReservationController(repo);
