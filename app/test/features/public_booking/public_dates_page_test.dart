import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_dates_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/widgets/public_calendar.dart';
import 'package:inkslot_app/features/public_booking/presentation/widgets/public_time_wheel.dart';

void main() {
  testWidgets('renders only API-provided days and slots', (tester) async {
    final today = _dateOnly(DateTime.now());
    final availableDay = today.add(const Duration(days: 1));
    final controller = PublicReservationController(
      _FakeRepository(
        availability: PublicAvailability(
          timezone: 'America/Guayaquil',
          days: <AvailabilityDay>[
            AvailabilityDay(
              date: availableDay,
              slots: <AvailabilitySlot>[_slot(15)],
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: PublicDatesPage(controller: controller, token: 'safe-token'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicCalendar), findsOneWidget);
    expect(find.byType(PublicTimeWheel), findsNothing);
    expect(find.text('Elige tu fecha'), findsOneWidget);

    controller.selectDate(availableDay);
    await tester.pump();

    expect(find.byType(PublicTimeWheel), findsOneWidget);
    expect(find.text('10:00'), findsWidgets);
  });

  testWidgets('renders safe empty state without invented slots', (
    tester,
  ) async {
    final controller = PublicReservationController(
      _FakeRepository(
        availability: const PublicAvailability(
          timezone: 'America/Guayaquil',
          days: <AvailabilityDay>[],
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: PublicDatesPage(controller: controller, token: 'safe-token'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO HAY HORARIOS DISPONIBLES'), findsOneWidget);
    expect(find.byType(PublicTimeWheel), findsNothing);
  });
}

AvailabilitySlot _slot(int hour) => AvailabilitySlot(
  startAt: DateTime.utc(2026, 10, 23, hour),
  endAt: DateTime.utc(2026, 10, 23, hour + 1),
);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _FakeRepository extends PublicReservationRepository {
  _FakeRepository({required this.availability}) : super(_NoopApiClient());

  final PublicAvailability availability;

  @override
  Future<PublicReservation> getReservation(String token) async =>
      PublicReservation(
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

  @override
  Future<PublicAvailability> getAvailability(
    String token, {
    required DateTime from,
    required DateTime to,
  }) async => availability;
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
