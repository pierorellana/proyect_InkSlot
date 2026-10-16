import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_page.dart';

void main() {
  testWidgets(
    'renders real requests, filters terminal closed items, and paginates',
    (tester) async {
      final repository = QueueRequestsRepository([
        BookingRequestPage(
          items: [_request('pending-1', BookingRequestStatus.pending)],
          nextCursor: 'next',
        ),
        BookingRequestPage(
          items: [
            _request(
              'closed-1',
              BookingRequestStatus.closed,
              name: 'Cerrada Ink',
            ),
            _request('cancelled-1', BookingRequestStatus.cancelled),
          ],
          nextCursor: null,
        ),
        BookingRequestPage(
          items: [
            _request(
              'closed-2',
              BookingRequestStatus.closed,
              name: 'Cerrada Ink',
            ),
            _request('cancelled-2', BookingRequestStatus.cancelled),
          ],
          nextCursor: null,
        ),
      ]);
      final controller = BookingRequestsController(repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(BookingRequestsPage(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Ink'), findsOneWidget);
      expect(find.text('PENDIENTE'), findsOneWidget);
      expect(find.text('Cargar más'), findsOneWidget);

      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();
      expect(find.text('Cargar más'), findsNothing);

      await tester.tap(find.text('Canceladas'));
      await tester.pumpAndSettle();
      expect(find.text('Cerrada Ink'), findsOneWidget);
      expect(find.text('CERRADA'), findsOneWidget);
      expect(find.text('CANCELADA'), findsOneWidget);
    },
  );

  testWidgets('shows safe API error and responsive content without overflow', (
    tester,
  ) async {
    final repository = QueueRequestsRepository(
      const [],
      error: const ApiException(
        statusCode: 400,
        code: 'BAD_REQUEST',
        message: 'No se pudieron cargar las solicitudes.',
      ),
    );
    final controller = BookingRequestsController(repository);
    addTearDown(controller.dispose);

    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
    });

    await tester.pumpWidget(_host(BookingRequestsPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('No se pudieron cargar las solicitudes.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: buildInkSlotTheme(),
  home: Scaffold(body: child),
);

class QueueRequestsRepository extends BookingRequestsRepository {
  QueueRequestsRepository(this.pages, {this.error}) : super(_NoopApiClient());

  final List<BookingRequestPage> pages;
  final Object? error;
  var _index = 0;

  @override
  Future<BookingRequestPage> list({
    BookingRequestStatus? status,
    String? cursor,
  }) async {
    if (error != null) throw error!;
    if (_index >= pages.length) {
      return const BookingRequestPage(items: [], nextCursor: null);
    }
    return pages[_index++];
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

BookingRequest _request(
  String id,
  BookingRequestStatus status, {
  String name = 'Ana Ink',
}) => BookingRequest(
  id: id,
  client: BookingRequestClient(
    id: 'client-$id',
    name: name,
    contactChannel: ContactChannel.instagram,
    contactValue: '@ana.ink',
  ),
  paymentReference: 'TRX-123',
  depositVerified: true,
  durationMinutes: 120,
  status: status,
  minDate: null,
  maxDate: null,
  allowedWeekdays: null,
  allowedWindows: null,
  createdAt: DateTime.utc(2026, 10, 16),
);
