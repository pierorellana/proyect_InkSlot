import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/domain/admin_user.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';
import 'package:inkslot_app/features/requests/presentation/link_ready_page.dart';
import 'package:inkslot_app/features/requests/presentation/new_booking_request_page.dart';

void main() {
  testWidgets('validates the client and deposit before creating', (
    tester,
  ) async {
    final repository = RecordingBookingRequestsRepository();
    final controller = BookingRequestsController(repository);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: Scaffold(body: NewBookingRequestHarness(controller: controller)),
      ),
    );

    await tester.ensureVisible(find.text('Crear solicitud'));
    await tester.tap(find.text('Crear solicitud'));
    await tester.pump();

    expect(find.text('Ingresa el nombre del cliente.'), findsOneWidget);
    expect(find.text('Confirma el anticipo para continuar.'), findsOneWidget);
    expect(repository.input, isNull);
  });

  testWidgets(
    'submits all request fields and keeps the token out of the route',
    (tester) async {
      final repository = RecordingBookingRequestsRepository();
      final controller = BookingRequestsController(repository);
      final session = AdminSessionController(RecordingAuthRepository());
      await session.restore();

      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildInkSlotTheme(),
          routerConfig: AppRouter.create(
            initialLocation: '/admin/requests/new',
            sessionController: session,
            bookingRequestsController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Ana Ink');
      await tester.enterText(textFields.at(1), '+593 99 123 4567');
      await tester.enterText(textFields.at(2), 'Transferencia 0045');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.text('Crear solicitud'));
      await tester.tap(find.text('Crear solicitud'));
      await tester.pumpAndSettle();

      expect(repository.input?.clientName, 'Ana Ink');
      expect(repository.input?.contactChannel, ContactChannel.whatsapp);
      expect(repository.input?.contactValue, '+593 99 123 4567');
      expect(repository.input?.paymentReference, 'Transferencia 0045');
      expect(repository.input?.depositVerified, isTrue);
      expect(repository.input?.durationMinutes, 180);
      expect(find.byType(LinkReadyPage), findsOneWidget);
      expect(find.textContaining('/r/secret-token'), findsOneWidget);
    },
  );

  testWidgets('supports all contact channels and channel-specific labels', (
    tester,
  ) async {
    final controller = BookingRequestsController(
      RecordingBookingRequestsRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: Scaffold(body: NewBookingRequestHarness(controller: controller)),
      ),
    );

    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<ContactChannel>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<ContactChannel>));
    await tester.pump();
    await tester.tap(find.text('Instagram').last);
    await tester.pump();

    expect(find.text('Usuario de Instagram'), findsOneWidget);
    expect(find.text('@usuario'), findsOneWidget);
  });
}

class NewBookingRequestHarness extends StatelessWidget {
  const NewBookingRequestHarness({required this.controller, super.key});

  final BookingRequestsController controller;

  @override
  Widget build(BuildContext context) =>
      NewBookingRequestPage(controller: controller);
}

class RecordingBookingRequestsRepository extends BookingRequestsRepository {
  RecordingBookingRequestsRepository() : super(_NoopApiClient());

  CreateBookingRequestInput? input;

  @override
  Future<BookingRequestActionResult> create(
    CreateBookingRequestInput input,
  ) async {
    this.input = input;
    return BookingRequestActionResult(
      request: BookingRequest(
        id: 'request-1',
        client: const BookingRequestClient(id: 'client-1', name: 'Ana Ink'),
        paymentReference: input.paymentReference,
        depositVerified: true,
        durationMinutes: input.durationMinutes,
        status: BookingRequestStatus.pending,
        minDate: null,
        maxDate: null,
        allowedWeekdays: null,
        allowedWindows: null,
        createdAt: DateTime.utc(2026, 10, 16),
      ),
      link: LinkReadyData(
        path: '/r/secret-token',
        expiresAt: DateTime.utc(2026, 10, 18),
      ),
    );
  }
}

class RecordingAuthRepository extends AuthRepository {
  RecordingAuthRepository() : super(_NoopApiClient());

  @override
  Future<AdminUser> currentUser() async =>
      const AdminUser(id: 'artist-1', name: 'Ink Artist', role: 'admin');
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
