import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_primary_button.dart';
import 'package:inkslot_app/features/public_booking/data/public_reservation_repository.dart';
import 'package:inkslot_app/features/public_booking/domain/public_appointment.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_result_page.dart';

void main() {
  testWidgets('loads a deep-linked appointment and exposes a safe result', (
    tester,
  ) async {
    final repository = _ResultRepository();
    final controller = PublicReservationController(repository);

    await tester.pumpWidget(
      _app(
        PublicResultPage(
          token: 'consumed-token',
          controller: controller,
          onReturnToDates: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.appointmentCalls, 1);
    expect(find.textContaining('Nos vemos el martes'), findsOneWidget);
    expect(find.text('Ver mi reserva'), findsOneWidget);
    expect(
      find.text('Guardar en mi calendario · Próximamente'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<InkSlotPrimaryButton>(find.byType(InkSlotPrimaryButton))
          .onPressed,
      isNull,
    );
    expect(find.text('Mar 20 oct'), findsOneWidget);
    expect(find.text('10:00 – 13:00'), findsOneWidget);
    expect(
      find.textContaining('Estamos terminando de registrarlo'),
      findsOneWidget,
    );

    await tester.tap(find.text('Ver mi reserva'));
    await tester.pumpAndSettle();
    expect(repository.appointmentCalls, 2);
  });

  testWidgets('maps offline result lookup and can retry', (tester) async {
    final repository = _ResultRepository(
      appointmentError: const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Sin conexión',
      ),
    );
    final controller = PublicReservationController(repository);

    await tester.pumpWidget(
      _app(
        PublicResultPage(
          token: 'consumed-token',
          controller: controller,
          onReturnToDates: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    repository.appointmentError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nos vemos el martes'), findsOneWidget);
  });

  testWidgets('renders a pending in-memory confirmation with reduced motion', (
    tester,
  ) async {
    final controller = PublicReservationController(_ResultRepository());
    controller // selection remains private; load the result through the API path.
        .loadAppointment('consumed-token');

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(
          PublicResultPage(
            token: 'consumed-token',
            controller: controller,
            onReturnToDates: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Reserva confirmada'), findsOneWidget);
    expect(
      find.textContaining('Estamos terminando de registrarlo'),
      findsOneWidget,
    );
  });
}

Widget _app(Widget child) => MediaQuery(
  data: const MediaQueryData(disableAnimations: true),
  child: MaterialApp(theme: buildInkSlotTheme(), home: child),
);

class _ResultRepository extends PublicReservationRepository {
  _ResultRepository({this.appointmentError}) : super(_NoopApiClient());

  Object? appointmentError;
  int appointmentCalls = 0;

  @override
  Future<PublicAppointment> getAppointment(String token) async {
    appointmentCalls += 1;
    if (appointmentError != null) throw appointmentError!;
    return PublicAppointment(
      status: 'confirmed',
      syncStatus: 'pending',
      startAt: DateTime.utc(2026, 10, 20, 15),
      endAt: DateTime.utc(2026, 10, 20, 18),
      timezone: 'America/Guayaquil',
    );
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
