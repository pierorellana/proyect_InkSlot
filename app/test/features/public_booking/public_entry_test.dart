import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/app.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_dates_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_entry_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_splash_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_welcome_page.dart';
import 'package:provider/provider.dart';
import 'package:inkslot_app/core/network/api_client.dart';

void main() {
  testWidgets('reduced-motion splash completes without waiting', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ChangeNotifierProvider(
            create: (_) => PublicEntryController(),
            child: PublicSplashPage(onFinished: () => completed = true),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets('deep links skip the splash and render the private welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp.router(
          theme: buildInkSlotTheme(),
          routerConfig: AppRouter.create(
            initialLocation: '/r/test-token',
            publicReservationController: _activePublicController(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(PublicWelcomePage), findsOneWidget);
    expect(find.text('SALTAR INTRO'), findsNothing);

    await tester.tap(find.text('Elegir fecha y hora'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicDatesPage), findsOneWidget);
    expect(find.text('Elige un día'), findsOneWidget);
  });

  testWidgets('root skip action navigates to the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(const InkSlotApp());
    await tester.tap(find.text('SALTAR INTRO'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(PublicWelcomePage), findsOneWidget);
  });
}

PublicReservationController _activePublicController() =>
    PublicReservationController(_ActivePublicRepository());

class _ActivePublicRepository extends PublicReservationRepository {
  _ActivePublicRepository() : super(_NoopApiClient());

  @override
  Future<PublicReservation> getReservation(String token) async =>
      PublicReservation(
        status: 'pending',
        artistDisplayName: 'Ink Artist',
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
