import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/widgets/inkslot_kit.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_dates_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/widgets/public_calendar.dart';
import 'package:inkslot_app/features/public_booking/presentation/widgets/public_time_wheel.dart';

void main() {
  testWidgets('shows the calendar and only API-provided slots', (tester) async {
    final today = _dateOnly(DateTime.now());
    final controller = PublicReservationController(
      _FakeRepository(
        availability: PublicAvailability(
          timezone: 'America/Guayaquil',
          days: <AvailabilityDay>[
            AvailabilityDay(date: today, slots: <AvailabilitySlot>[_slot(15)]),
          ],
        ),
      ),
    );
    AvailabilitySlot? reviewed;

    await tester.pumpWidget(
      _app(
        PublicDatesPage(
          controller: controller,
          token: 'safe-token',
          onReview: () => reviewed = controller.selectedSlot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicCalendar), findsOneWidget);
    expect(find.byType(PublicTimeWheel), findsNothing);
    expect(find.text('Elige un día'), findsOneWidget);
    expect(find.text('Selecciona un día'), findsOneWidget);

    controller.selectDate(today);
    await tester.pumpAndSettle();
    expect(find.textContaining('Ver horarios del'), findsOneWidget);

    await tester.tap(find.textContaining('Ver horarios del'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicTimeWheel), findsOneWidget);
    expect(find.text('10:00'), findsWidgets);
    expect(find.text('1 de 1 horarios libres'.toUpperCase()), findsOneWidget);
    expect(find.textContaining('hora de Ecuador'), findsNothing);

    await tester.tap(find.text('10:00').first);
    await tester.pumpAndSettle();
    expect(reviewed, same(controller.selectedSlot));
    expect(reviewed?.startAt, DateTime.utc(2026, 10, 23, 15));
  });

  testWidgets('back from the time step returns to the calendar', (
    tester,
  ) async {
    final today = _dateOnly(DateTime.now());
    final controller = PublicReservationController(
      _FakeRepository(
        availability: PublicAvailability(
          timezone: 'America/Guayaquil',
          days: <AvailabilityDay>[
            AvailabilityDay(date: today, slots: <AvailabilitySlot>[_slot(15)]),
          ],
        ),
      ),
    );
    await tester.pumpWidget(
      _app(PublicDatesPage(controller: controller, token: 'safe-token')),
    );
    await tester.pumpAndSettle();
    controller.selectDate(today);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ver horarios del'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicTimeWheel), findsOneWidget);

    await tester.tap(find.byType(InkSlotIconButton).first);
    await tester.pumpAndSettle();
    expect(find.byType(PublicTimeWheel), findsNothing);
    expect(find.byType(PublicCalendar), findsOneWidget);
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
      _app(PublicDatesPage(controller: controller, token: 'safe-token')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay horarios disponibles'), findsOneWidget);
    expect(find.byType(PublicTimeWheel), findsNothing);
  });

  testWidgets('shows the unverifiable agenda state with retry', (tester) async {
    final controller = PublicReservationController(
      _FakeRepository(
        availability: const PublicAvailability(
          timezone: 'America/Guayaquil',
          days: <AvailabilityDay>[],
        ),
        availabilityError: const ApiException(
          code: 'CALENDAR_UNAVAILABLE',
          message: 'Sin agenda',
        ),
      ),
    );
    await tester.pumpWidget(
      _app(PublicDatesPage(controller: controller, token: 'safe-token')),
    );
    await tester.pumpAndSettle();

    expect(find.text('No pudimos verificar la agenda'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(PublicCalendar), findsNothing);
  });
}

Widget _app(Widget child) => MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: MaterialApp(theme: buildInkSlotTheme(), home: child),
);

AvailabilitySlot _slot(int hour) => AvailabilitySlot(
  startAt: DateTime.utc(2026, 10, 23, hour),
  endAt: DateTime.utc(2026, 10, 23, hour + 1),
);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class _FakeRepository extends PublicReservationRepository {
  _FakeRepository({required this.availability, this.availabilityError})
    : super(_NoopApiClient());

  final PublicAvailability availability;
  final Object? availabilityError;

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
  }) async {
    if (availabilityError != null) throw availabilityError!;
    return availability;
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
