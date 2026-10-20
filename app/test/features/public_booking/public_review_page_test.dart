import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_appointment.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_confirmation.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_review_page.dart';

void main() {
  testWidgets('renders the review ticket and confirms the selected slot', (
    tester,
  ) async {
    final repository = _ReviewRepository();
    final controller = await _selectedController(repository);
    var confirmed = false;

    await tester.pumpWidget(
      _app(
        PublicReviewPage(
          token: 'safe-token',
          controller: controller,
          onBack: () {},
          onConfirmed: () => confirmed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gio Ink'), findsOneWidget);
    expect(find.text('Revisa y confirma'), findsOneWidget);
    expect(find.text('Mar 20'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('13:00'), findsOneWidget);
    expect(find.text('Zona'), findsNothing);
    expect(find.text('Estudio'), findsNothing);
    expect(find.text('Confirmar cita'), findsOneWidget);

    await tester.tap(find.text('Confirmar cita'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(controller.confirmationStatus, PublicConfirmationStatus.confirmed);
  });

  testWidgets('deep-linked review without a slot shows a safe fallback', (
    tester,
  ) async {
    final controller = PublicReservationController(_ReviewRepository());
    await controller.loadReservation('safe-token');
    var returned = false;

    await tester.pumpWidget(
      _app(
        PublicReviewPage(
          token: 'safe-token',
          controller: controller,
          onBack: () => returned = true,
          onConfirmed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Elige un horario primero'), findsOneWidget);
    expect(find.text('Confirmar cita'), findsNothing);

    await tester.tap(find.text('Volver'));
    expect(returned, isTrue);
  });

  testWidgets('shows a conflict with retry and back actions', (tester) async {
    final repository = _ReviewRepository(
      confirmationError: const ApiException(
        statusCode: 409,
        code: 'SLOT_UNAVAILABLE',
        message: 'Horario no disponible',
      ),
    );
    final controller = await _selectedController(repository);
    var returned = false;

    await tester.pumpWidget(
      _app(
        PublicReviewPage(
          token: 'safe-token',
          controller: controller,
          onBack: () => returned = true,
          onConfirmed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar cita'));
    await tester.pumpAndSettle();

    expect(find.text('Ese horario se acaba de ocupar'), findsOneWidget);
    expect(
      find.textContaining('Otra persona confirmó las 10:00'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsNothing);
    await tester.tap(find.text('Ver horarios actualizados'));
    expect(returned, isTrue);
  });

  testWidgets('renders without motion when accessibility disables animations', (
    tester,
  ) async {
    final controller = await _selectedController(_ReviewRepository());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(
          PublicReviewPage(
            token: 'safe-token',
            controller: controller,
            onBack: () {},
            onConfirmed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revisa y confirma'), findsOneWidget);
  });

  testWidgets('keeps the confirm action available after an agenda failure', (
    tester,
  ) async {
    final repository = _ReviewRepository(
      confirmationError: const ApiException(
        code: 'CALENDAR_UNAVAILABLE',
        message: 'Agenda no verificable',
      ),
    );
    final controller = await _selectedController(repository);

    await tester.pumpWidget(
      _app(
        PublicReviewPage(
          token: 'safe-token',
          controller: controller,
          onBack: () {},
          onConfirmed: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar cita'));
    await tester.pumpAndSettle();

    expect(find.text('No pudimos verificar la agenda'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}

Widget _app(Widget child) => MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: MaterialApp(theme: buildInkSlotTheme(), home: child),
);

Future<PublicReservationController> _selectedController(
  _ReviewRepository repository,
) async {
  final controller = PublicReservationController(repository);
  await controller.loadReservation('safe-token');
  await controller.loadAvailability('safe-token', _date, _date);
  controller.selectSlot(repository.slot);
  return controller;
}

final _date = DateTime(2026, 10, 20);

class _ReviewRepository extends PublicReservationRepository {
  _ReviewRepository({this.confirmationError}) : super(_NoopApiClient());

  final AvailabilitySlot slot = AvailabilitySlot(
    startAt: DateTime.utc(2026, 10, 20, 15),
    endAt: DateTime.utc(2026, 10, 20, 18),
  );
  Object? confirmationError;

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
  }) async => PublicAvailability(
    timezone: 'America/Guayaquil',
    days: <AvailabilityDay>[
      AvailabilityDay(date: _date, slots: <AvailabilitySlot>[slot]),
    ],
  );

  @override
  Future<PublicConfirmation> confirmReservation(
    String token,
    DateTime startAt, {
    required String idempotencyKey,
  }) async {
    if (confirmationError != null) throw confirmationError!;
    return PublicConfirmation(
      status: 'confirmed',
      syncStatus: 'pending',
      startAt: startAt,
      endAt: slot.endAt,
      timezone: 'America/Guayaquil',
    );
  }

  @override
  Future<PublicAppointment> getAppointment(String token) async =>
      PublicAppointment(
        status: 'confirmed',
        syncStatus: 'pending',
        startAt: slot.startAt,
        endAt: slot.endAt,
        timezone: 'America/Guayaquil',
      );
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
