import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_request_detail_page.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';

void main() {
  testWidgets('renders administrative detail, payment reference and audit', (
    tester,
  ) async {
    final detail = _detail(BookingRequestStatus.pending);
    final controller = BookingRequestsController(
      DetailRequestsRepository(detail: detail),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        BookingRequestDetailPage(
          controller: controller,
          requestId: 'request-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Ink'), findsAtLeastNWidgets(1));
    expect(find.text('TRX-123'), findsOneWidget);
    expect(find.text('Solicitud creada'), findsOneWidget);
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('Anticipo'), findsOneWidget);
    expect(find.textContaining('raw-'), findsNothing);
  });

  testWidgets('confirms revoke and surfaces a safe 409 message', (
    tester,
  ) async {
    final controller = BookingRequestsController(
      DetailRequestsRepository(
        detail: _detail(BookingRequestStatus.pending),
        revokeError: const ApiException(
          statusCode: 409,
          code: 'ALREADY_BOOKED',
          message: 'La solicitud ya fue reservada.',
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        BookingRequestDetailPage(
          controller: controller,
          requestId: 'request-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revocar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Revocar el enlace?'), findsOneWidget);

    await tester.tap(find.text('Revocar enlace'));
    await tester.pumpAndSettle();

    expect(find.text('La solicitud ya fue reservada.'), findsOneWidget);
    expect(find.textContaining('token'), findsNothing);
  });

  testWidgets('adapts detail layout to a narrow viewport', (tester) async {
    final controller = BookingRequestsController(
      DetailRequestsRepository(detail: _detail(BookingRequestStatus.pending)),
    );
    addTearDown(controller.dispose);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
    });

    await tester.pumpWidget(
      _host(
        BookingRequestDetailPage(
          controller: controller,
          requestId: 'request-1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Enlace activo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: buildInkSlotTheme(),
  home: Scaffold(body: child),
);

class DetailRequestsRepository extends BookingRequestsRepository {
  DetailRequestsRepository({
    required BookingRequestDetail detail,
    this.revokeError,
  }) : detailValue = detail,
       super(_NoopApiClient());

  BookingRequestDetail detailValue;
  final Object? revokeError;

  @override
  Future<BookingRequestDetail> detail(String id) async => detailValue;

  @override
  Future<BookingRequest> revoke(String id) async {
    if (revokeError != null) throw revokeError!;
    detailValue = BookingRequestDetail(
      request: _request(BookingRequestStatus.cancelled),
      currentLink: detailValue.currentLink,
      audit: detailValue.audit,
    );
    return detailValue.request;
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

BookingRequestDetail _detail(BookingRequestStatus status) =>
    BookingRequestDetail(
      request: _request(status),
      currentLink: CurrentBookingLink(
        status: BookingLinkStatus.active,
        expiresAt: DateTime.utc(2026, 10, 18, 12),
      ),
      audit: [
        BookingRequestAuditEntry(
          action: 'created',
          createdAt: DateTime.utc(2026, 10, 16, 10),
        ),
      ],
    );

BookingRequest _request(BookingRequestStatus status) => BookingRequest(
  id: 'request-1',
  client: const BookingRequestClient(
    id: 'client-1',
    name: 'Ana Ink',
    contactChannel: ContactChannel.instagram,
    contactValue: '@ana.ink',
  ),
  paymentReference: 'TRX-123',
  depositVerified: true,
  durationMinutes: 120,
  status: status,
  minDate: DateTime.utc(2026, 10, 20),
  maxDate: DateTime.utc(2026, 10, 20),
  allowedWeekdays: const [1, 2],
  allowedWindows: const [
    BookingRestrictionWindow(startLocal: '10:00', endLocal: '13:00'),
  ],
  createdAt: DateTime.utc(2026, 10, 16),
);
