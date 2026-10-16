import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_controller.dart';

void main() {
  test(
    'loads confirmed appointments and preserves the selected filter',
    () async {
      final repository = FakeAppointmentsRepository(
        pages: [
          AdminAppointmentPage(
            items: [_appointment('confirmed-1')],
            nextCursor: 'next',
          ),
          const AdminAppointmentPage(items: [], nextCursor: null),
        ],
      );
      final controller = AdminAppointmentsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      expect(controller.status, AdminAppointmentsStatus.loaded);
      expect(controller.filter, AdminAppointmentStatus.confirmed);
      expect(repository.filters, [AdminAppointmentStatus.confirmed]);

      await controller.setFilter(AdminAppointmentStatus.completed);
      expect(controller.filter, AdminAppointmentStatus.completed);
      expect(controller.status, AdminAppointmentsStatus.empty);
      expect(repository.filters, [
        AdminAppointmentStatus.confirmed,
        AdminAppointmentStatus.completed,
      ]);
    },
  );

  test('paginates and ignores duplicate appointments', () async {
    final repository = FakeAppointmentsRepository(
      pages: [
        AdminAppointmentPage(
          items: [_appointment('appointment-1')],
          nextCursor: 'next',
        ),
        AdminAppointmentPage(
          items: [_appointment('appointment-1'), _appointment('appointment-2')],
          nextCursor: null,
        ),
      ],
    );
    final controller = AdminAppointmentsController(repository);
    addTearDown(controller.dispose);

    await controller.load();
    await controller.loadMore();

    expect(controller.items.map((item) => item.id), [
      'appointment-1',
      'appointment-2',
    ]);
    expect(controller.nextCursor, isNull);
    expect(repository.cursors, [null, 'next']);
  });

  test('exposes empty, safe error, and unauthorized session states', () async {
    final emptyController = AdminAppointmentsController(
      FakeAppointmentsRepository(
        pages: const [AdminAppointmentPage(items: [], nextCursor: null)],
      ),
    );
    addTearDown(emptyController.dispose);
    await emptyController.load();
    expect(emptyController.status, AdminAppointmentsStatus.empty);

    final errorController = AdminAppointmentsController(
      FakeAppointmentsRepository(
        pages: const [],
        error: const ApiException(
          statusCode: 503,
          code: 'SERVICE_UNAVAILABLE',
          message: 'El calendario no está disponible.',
        ),
      ),
    );
    addTearDown(errorController.dispose);
    await errorController.load();
    expect(errorController.status, AdminAppointmentsStatus.error);
    expect(errorController.errorMessage, 'El calendario no está disponible.');

    final unauthorizedController = AdminAppointmentsController(
      FakeAppointmentsRepository(
        pages: const [],
        error: const ApiException(
          statusCode: 401,
          code: 'AUTH_INVALID',
          message: 'Sesión expirada.',
        ),
      ),
    );
    addTearDown(unauthorizedController.dispose);
    await unauthorizedController.load();
    expect(unauthorizedController.sessionExpired, isTrue);
    expect(unauthorizedController.errorMessage, 'Sesión expirada.');
  });

  test('does not issue a second request while loading', () async {
    final repository = BlockingAppointmentsRepository();
    final controller = AdminAppointmentsController(repository);
    addTearDown(controller.dispose);

    final first = controller.load();
    final second = controller.load();
    expect(repository.calls, 1);
    repository.complete(
      const AdminAppointmentPage(items: [], nextCursor: null),
    );
    await Future.wait([first, second]);
  });
}

class FakeAppointmentsRepository extends AdminAppointmentsRepository {
  FakeAppointmentsRepository({required this.pages, this.error})
    : super(_NoopApiClient());

  final List<AdminAppointmentPage> pages;
  final Object? error;
  final List<AdminAppointmentStatus> filters = <AdminAppointmentStatus>[];
  final List<String?> cursors = <String?>[];
  var _index = 0;

  @override
  Future<AdminAppointmentPage> list({
    AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
    String? cursor,
  }) async {
    filters.add(status);
    cursors.add(cursor);
    if (error != null) throw error!;
    return _index < pages.length
        ? pages[_index++]
        : const AdminAppointmentPage(items: [], nextCursor: null);
  }
}

class BlockingAppointmentsRepository extends AdminAppointmentsRepository {
  BlockingAppointmentsRepository() : super(_NoopApiClient());

  final _completer = Completer<AdminAppointmentPage>();
  var calls = 0;

  @override
  Future<AdminAppointmentPage> list({
    AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
    String? cursor,
  }) {
    calls += 1;
    return _completer.future;
  }

  void complete(AdminAppointmentPage page) {
    _completer.complete(page);
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

AdminAppointment _appointment(String id) => AdminAppointment(
  id: id,
  clientName: 'Ana Ink',
  startAt: DateTime.utc(2026, 10, 20, 15),
  endAt: DateTime.utc(2026, 10, 20, 17),
  durationMinutes: 120,
  status: AdminAppointmentStatus.confirmed,
  syncStatus: AdminAppointmentSyncStatus.synced,
  version: 1,
);
