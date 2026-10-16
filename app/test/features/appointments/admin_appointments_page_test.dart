import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_controller.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_page.dart';

void main() {
  testWidgets('renders cards and reloads the selected status filter', (
    tester,
  ) async {
    final repository = QueueAppointmentsRepository([
      AdminAppointmentPage(
        items: [_appointment('confirmed-1')],
        nextCursor: null,
      ),
      AdminAppointmentPage(
        items: [
          _appointment('completed-1', status: AdminAppointmentStatus.completed),
        ],
        nextCursor: null,
      ),
    ]);
    final controller = AdminAppointmentsController(repository);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(AdminAppointmentsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Ink'), findsOneWidget);
    expect(find.text('CONFIRMADA'), findsOneWidget);
    expect(find.text('Sincronizada'), findsOneWidget);

    await tester.tap(find.text('Completadas'));
    await tester.pumpAndSettle();

    expect(controller.filter, AdminAppointmentStatus.completed);
    expect(find.text('COMPLETADA'), findsOneWidget);
    expect(repository.statuses, [
      AdminAppointmentStatus.confirmed,
      AdminAppointmentStatus.completed,
    ]);
  });

  testWidgets('shows empty and safe error states without overflow', (
    tester,
  ) async {
    final emptyController = AdminAppointmentsController(
      QueueAppointmentsRepository([
        const AdminAppointmentPage(items: [], nextCursor: null),
      ]),
    );
    addTearDown(emptyController.dispose);
    await tester.pumpWidget(
      _host(AdminAppointmentsPage(controller: emptyController)),
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay citas confirmadas.'), findsOneWidget);

    final errorController = AdminAppointmentsController(
      QueueAppointmentsRepository(
        const [],
        error: ApiException(
          statusCode: 500,
          code: 'SERVER_ERROR',
          message: 'No se pudieron cargar las citas.',
        ),
      ),
    );
    addTearDown(errorController.dispose);
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
    });
    await tester.pumpWidget(
      _host(AdminAppointmentsPage(controller: errorController)),
    );
    await tester.pumpAndSettle();
    expect(errorController.status, AdminAppointmentsStatus.error);
    expect(errorController.errorMessage, 'No se pudieron cargar las citas.');
    expect(find.text('No se pudieron cargar las citas.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paginates without adding mutation controls', (tester) async {
    final controller = AdminAppointmentsController(
      QueueAppointmentsRepository([
        AdminAppointmentPage(
          items: [_appointment('confirmed-1')],
          nextCursor: 'next',
        ),
        AdminAppointmentPage(
          items: [_appointment('confirmed-2')],
          nextCursor: null,
        ),
      ]),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(AdminAppointmentsPage(controller: controller)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Cargar más'), findsOneWidget);
    expect(find.text('Cancelar'), findsNothing);
    expect(find.text('Reprogramar'), findsNothing);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(find.text('Cargar más'), findsNothing);
    expect(find.text('Ana Ink'), findsNWidgets(2));
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: buildInkSlotTheme(),
  home: Scaffold(body: child),
);

class QueueAppointmentsRepository extends AdminAppointmentsRepository {
  QueueAppointmentsRepository(this.pages, {this.error})
    : super(_NoopApiClient());

  final List<AdminAppointmentPage> pages;
  final Object? error;
  final List<AdminAppointmentStatus> statuses = <AdminAppointmentStatus>[];
  var _index = 0;

  @override
  Future<AdminAppointmentPage> list({
    AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
    String? cursor,
  }) async {
    statuses.add(status);
    if (error != null) throw error!;
    return _index < pages.length
        ? pages[_index++]
        : const AdminAppointmentPage(items: [], nextCursor: null);
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

AdminAppointment _appointment(
  String id, {
  AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
}) => AdminAppointment(
  id: id,
  clientName: 'Ana Ink',
  startAt: DateTime.utc(2026, 10, 20, 15),
  endAt: DateTime.utc(2026, 10, 20, 17),
  durationMinutes: 120,
  status: status,
  syncStatus: AdminAppointmentSyncStatus.synced,
  version: 1,
);
