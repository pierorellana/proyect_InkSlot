import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_appointment.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_result_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_review_page.dart';

void main() {
  testWidgets('deep-linked review route falls back without inventing a slot', (
    tester,
  ) async {
    final controller = PublicReservationController(_RouterRepository());
    final router = AppRouter.create(
      initialLocation: '/r/deep-token/review',
      publicReservationController: controller,
    );
    addTearDown(router.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicReviewPage), findsOneWidget);
    expect(find.text('ELIGE UN HORARIO PRIMERO'), findsOneWidget);
    expect(find.text('Confirmar reserva'), findsNothing);
  });

  testWidgets('deep-linked result route loads only the safe appointment DTO', (
    tester,
  ) async {
    final controller = PublicReservationController(_RouterRepository());
    final router = AppRouter.create(
      initialLocation: '/r/consumed-token/result',
      publicReservationController: controller,
    );
    addTearDown(router.dispose);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PublicResultPage), findsOneWidget);
    expect(find.text('Tu espacio está apartado.'), findsOneWidget);
  });
}

class _RouterRepository extends PublicReservationRepository {
  _RouterRepository() : super(_NoopApiClient());

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
  Future<PublicAppointment> getAppointment(String token) async =>
      PublicAppointment(
        status: 'confirmed',
        syncStatus: 'synced',
        startAt: DateTime.utc(2026, 10, 20, 15),
        endAt: DateTime.utc(2026, 10, 20, 18),
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
