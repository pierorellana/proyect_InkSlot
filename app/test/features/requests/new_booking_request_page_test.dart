import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_kit.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/domain/admin_user.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';
import 'package:inkslot_app/features/requests/presentation/link_ready_page.dart';
import 'package:inkslot_app/features/requests/presentation/new_booking_request_page.dart';
import 'package:inkslot_app/features/requests/presentation/widgets/contact_channel_field.dart';

Widget _app({required Widget home}) => MaterialApp(
  theme: buildInkSlotTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: home,
);

void usePhoneView(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('disables creation and lists what is missing', (tester) async {
    usePhoneView(tester);
    final repository = RecordingBookingRequestsRepository();
    final controller = BookingRequestsController(repository);

    await tester.pumpWidget(
      _app(
        home: Scaffold(body: NewBookingRequestHarness(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Falta: nombre del cliente · dato de contacto · confirmar anticipo',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Crear y generar enlace'), warnIfMissed: false);
    await tester.pump();
    expect(repository.input, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Ana Ink');
    await tester.enterText(find.byType(TextField).at(1), '+593 99 123 4567');
    await tester.pump();
    expect(find.text('Falta: confirmar anticipo'), findsOneWidget);
  });

  testWidgets('keeps the action bar below the form when the keyboard is open', (
    tester,
  ) async {
    usePhoneView(tester);
    final controller = BookingRequestsController(
      RecordingBookingRequestsRepository(),
    );

    await tester.pumpWidget(
      _app(
        home: MediaQuery(
          data: const MediaQueryData(viewInsets: EdgeInsets.only(bottom: 360)),
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: NewBookingRequestHarness(controller: controller),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameField = tester.getRect(find.byType(TextField).first);
    final actionButton = tester.getRect(find.text('Crear y generar enlace'));

    expect(actionButton.top, greaterThanOrEqualTo(nameField.bottom));
  });

  testWidgets(
    'submits all request fields and keeps the token out of the route',
    (tester) async {
      usePhoneView(tester);
      final repository = RecordingBookingRequestsRepository();
      final controller = BookingRequestsController(repository);
      final session = AdminSessionController(RecordingAuthRepository());
      await session.restore();

      await tester.pumpWidget(
        MaterialApp.router(
          theme: buildInkSlotTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          routerConfig: AppRouter.create(
            initialLocation: '/admin/requests/new',
            sessionController: session,
            bookingRequestsController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Ana Ink');
      await tester.enterText(textFields.at(1), '+593 99 123 4567');
      await tester.enterText(textFields.at(2), 'Transferencia 0045');
      await tester.ensureVisible(find.byType(InkSlotSwitch).first);
      await tester.tap(find.byType(InkSlotSwitch).first);
      await tester.pump();
      await tester.tap(find.text('Crear y generar enlace'));
      await tester.pumpAndSettle();

      expect(repository.input?.clientName, 'Ana Ink');
      expect(repository.input?.contactChannel, ContactChannel.whatsapp);
      expect(repository.input?.contactValue, '+593 99 123 4567');
      expect(repository.input?.paymentReference, 'Transferencia 0045');
      expect(repository.input?.depositVerified, isTrue);
      expect(repository.input?.durationMinutes, 180);
      expect(find.byType(LinkReadyPage), findsOneWidget);
      expect(find.textContaining('/r/secret-token'), findsOneWidget);
      expect(find.textContaining('Ana.'), findsOneWidget);
    },
  );

  testWidgets('supports the available contact channels and labels', (
    tester,
  ) async {
    usePhoneView(tester);
    final controller = BookingRequestsController(
      RecordingBookingRequestsRepository(),
    );
    await tester.pumpWidget(
      _app(
        home: Scaffold(body: NewBookingRequestHarness(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Número de WhatsApp'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Correo'), findsOneWidget);
    expect(find.text('Instagram'), findsNothing);
    expect(find.text('Teléfono'), findsNothing);
    await tester.tap(find.text('Correo'));
    await tester.pumpAndSettle();

    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('cliente@correo.com'), findsOneWidget);
  });

  testWidgets('clears the contact value when switching channels', (
    tester,
  ) async {
    usePhoneView(tester);
    final controller = BookingRequestsController(
      RecordingBookingRequestsRepository(),
    );
    await tester.pumpWidget(
      _app(
        home: Scaffold(body: NewBookingRequestHarness(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Correo'));
    await tester.enterText(find.byType(TextField).at(1), 'cliente@correo.com');
    await tester.tap(find.text('WhatsApp'));
    await tester.pumpAndSettle();

    expect(find.text('cliente@correo.com'), findsNothing);
    expect(find.text('Número de WhatsApp'), findsOneWidget);
  });

  test('rejects an email as a WhatsApp value', () {
    expect(
      ContactChannelField.validate(
        ContactChannel.whatsapp,
        'cliente@correo.com',
      ),
      isNotNull,
    );
  });

  testWidgets('adjusts the duration in 30 minute steps', (tester) async {
    usePhoneView(tester);
    final controller = BookingRequestsController(
      RecordingBookingRequestsRepository(),
    );
    await tester.pumpWidget(
      _app(
        home: Scaffold(body: NewBookingRequestHarness(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.bySemanticsLabel('Sumar 30 minutos'));
    await tester.tap(find.bySemanticsLabel('Sumar 30 minutos'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 h 30 min'), findsOneWidget);
    await tester.tap(find.text('1 h'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 h 00 min'), findsOneWidget);
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
