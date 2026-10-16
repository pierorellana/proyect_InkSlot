import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';

void main() {
  test('loads pages, appends the cursor, and removes duplicate ids', () async {
    final repository = FakeBookingRequestsRepository(
      listPages: [
        BookingRequestPage(
          items: [_request('request-1')],
          nextCursor: 'page-2',
        ),
        BookingRequestPage(
          items: [_request('request-1'), _request('request-2')],
          nextCursor: null,
        ),
      ],
    );
    final controller = BookingRequestsController(repository);

    await controller.load();
    expect(controller.listStatus, BookingRequestsListStatus.ready);
    expect(controller.nextCursor, 'page-2');
    expect(controller.items, hasLength(1));

    await controller.loadMore();
    expect(controller.items.map((item) => item.id), ['request-1', 'request-2']);
    expect(controller.nextCursor, isNull);
    expect(repository.cursors, [null, 'page-2']);
  });

  test('passes the selected status filter to the repository', () async {
    final repository = FakeBookingRequestsRepository(
      listPages: [
        BookingRequestPage(items: [_request('request-1')], nextCursor: null),
      ],
    );
    final controller = BookingRequestsController(repository);

    await controller.load(status: BookingRequestStatus.expired);

    expect(controller.statusFilter, BookingRequestStatus.expired);
    expect(repository.statuses, [BookingRequestStatus.expired]);
  });

  test('returns an ephemeral link for create and renew', () async {
    final repository = FakeBookingRequestsRepository(
      createResult: _actionResult('created'),
      renewResult: _actionResult('renewed'),
    );
    final controller = BookingRequestsController(repository);
    const input = CreateBookingRequestInput(
      clientName: 'Ana Ink',
      contactChannel: ContactChannel.instagram,
      contactValue: '@ana',
      depositVerified: true,
      durationMinutes: 120,
    );

    final created = await controller.create(input);
    final renewed = await controller.renew('request-1', ttlHours: 24);

    expect(created?.path, '/r/raw-create-token');
    expect(renewed?.path, '/r/raw-renew-token');
    expect(controller.mutationStatus, BookingRequestMutationStatus.success);
    expect(repository.createdInput?.clientName, 'Ana Ink');
    expect(repository.renewedId, 'request-1');
  });

  test(
    'keeps list, detail, and mutation state independent on errors',
    () async {
      final repository = FakeBookingRequestsRepository(
        listError: const ApiException(
          statusCode: 503,
          code: 'SERVICE_UNAVAILABLE',
          message: 'No disponible',
        ),
        detailResult: BookingRequestDetail(
          request: _request('request-1'),
          currentLink: null,
          audit: const [],
        ),
        revokeError: const ApiException(
          statusCode: 409,
          code: 'ALREADY_BOOKED',
          message: 'Ya reservada',
        ),
      );
      final controller = BookingRequestsController(repository);

      await controller.load();
      await controller.loadDetail('request-1');
      await controller.revoke('request-1');

      expect(controller.listStatus, BookingRequestsListStatus.error);
      expect(controller.detailStatus, BookingRequestDetailStatus.ready);
      expect(controller.mutationStatus, BookingRequestMutationStatus.error);
      expect(controller.listError, 'No disponible');
      expect(controller.mutationError, 'Ya reservada');
    },
  );

  test('marks the session boundary when the API returns 401', () async {
    final repository = FakeBookingRequestsRepository(
      detailError: const ApiException(
        statusCode: 401,
        code: 'AUTH_INVALID',
        message: 'Sesión expirada',
      ),
    );
    final controller = BookingRequestsController(repository);

    await controller.loadDetail('request-1');

    expect(controller.sessionExpired, isTrue);
    expect(controller.detailStatus, BookingRequestDetailStatus.error);
    expect(controller.detailError, 'Sesión expirada');
  });
}

class FakeBookingRequestsRepository extends BookingRequestsRepository {
  FakeBookingRequestsRepository({
    this.listPages = const <BookingRequestPage>[],
    this.listError,
    this.detailResult,
    this.detailError,
    this.createResult,
    this.renewResult,
    this.revokeResult,
    this.revokeError,
  }) : super(_NoopApiClient());

  final List<BookingRequestPage> listPages;
  final Object? listError;
  final BookingRequestDetail? detailResult;
  final Object? detailError;
  final BookingRequestActionResult? createResult;
  final BookingRequestActionResult? renewResult;
  final BookingRequest? revokeResult;
  final Object? revokeError;
  final List<String?> cursors = <String?>[];
  final List<BookingRequestStatus?> statuses = <BookingRequestStatus?>[];
  CreateBookingRequestInput? createdInput;
  String? renewedId;

  @override
  Future<BookingRequestPage> list({
    BookingRequestStatus? status,
    String? cursor,
  }) async {
    cursors.add(cursor);
    statuses.add(status);
    if (listError != null) throw listError!;
    return listPages[cursors.length - 1];
  }

  @override
  Future<BookingRequestDetail> detail(String id) async {
    if (detailError != null) throw detailError!;
    return detailResult!;
  }

  @override
  Future<BookingRequestActionResult> create(
    CreateBookingRequestInput input,
  ) async {
    createdInput = input;
    return createResult!;
  }

  @override
  Future<BookingRequestActionResult> renew(
    String id, {
    int? tokenTtlHours,
  }) async {
    renewedId = id;
    return renewResult!;
  }

  @override
  Future<BookingRequest> revoke(String id) async {
    if (revokeError != null) throw revokeError!;
    return revokeResult ?? _request(id);
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
  }) async => <String, dynamic>{};
}

BookingRequest _request(String id) => BookingRequest(
  id: id,
  client: const BookingRequestClient(id: 'client-1', name: 'Ana Ink'),
  paymentReference: null,
  depositVerified: true,
  durationMinutes: 120,
  status: BookingRequestStatus.pending,
  minDate: null,
  maxDate: null,
  allowedWeekdays: null,
  allowedWindows: null,
  createdAt: DateTime.utc(2026, 10, 16),
);

BookingRequestActionResult _actionResult(String id) =>
    BookingRequestActionResult(
      request: _request(id),
      link: LinkReadyData(
        path: id == 'created' ? '/r/raw-create-token' : '/r/raw-renew-token',
        expiresAt: DateTime.utc(2026, 10, 17),
      ),
    );
