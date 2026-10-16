import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/agenda/domain/availability.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointment_detail_controller.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointment_detail_page.dart';

void main() {
  group('AdminAppointmentsRepository detail actions', () {
    test('calls the detail, reschedule and transition endpoints', () async {
      final api = RecordingApi();
      final repository = AdminAppointmentsRepository(api);

      final detail = await repository.detail('a 1');
      expect(api.gets.single, '/admin/appointments/a%201');
      expect(detail.client.name, 'Ana Ink');
      expect(detail.client.contactLabel, '@ana');

      await repository.reschedule(
        'a1',
        startAt: DateTime.utc(2026, 10, 21, 15),
        version: 3,
      );
      expect(api.patched.single, '/admin/appointments/a1/reschedule');
      expect(api.lastBody, {
        'startAt': '2026-10-21T15:00:00.000Z',
        'version': 3,
      });

      await repository.complete('a1', version: 3);
      await repository.noShow('a1', version: 3);
      await repository.cancel('a1', version: 3);
      expect(api.posted, [
        '/admin/appointments/a1/complete',
        '/admin/appointments/a1/no-show',
        '/admin/appointments/a1/cancel',
      ]);
      expect(api.lastBody, {'version': 3});
    });

    test('retries only the open sync issue of the appointment', () async {
      final api = RecordingApi()
        ..issues = [_issue('i1', 'other'), _issue('i2', 'a1')];
      await AdminAppointmentsRepository(api).retrySync('a1');
      expect(api.gets, contains('/admin/sync-issues?status=open'));
      expect(api.posted, ['/admin/sync-issues/i2/retry']);
    });
  });

  group('AdminAppointmentDetailController', () {
    test('loads, mutates and keeps the server detail', () async {
      final repository = FakeRepository();
      final controller = AdminAppointmentDetailController(repository);
      await controller.load('a1');
      expect(controller.detail!.status, AdminAppointmentStatus.confirmed);

      expect(await controller.noShow(), isTrue);
      expect(controller.detail!.status, AdminAppointmentStatus.noShow);
      expect(repository.versions, [1]);
    });

    test('reports conflicts without replacing the detail', () async {
      final repository = FakeRepository()..failAction = true;
      final controller = AdminAppointmentDetailController(repository);
      await controller.load('a1');
      expect(await controller.cancel(), isFalse);
      expect(controller.actionError, 'El horario ya no está disponible');
      expect(controller.detail!.status, AdminAppointmentStatus.confirmed);
    });

    test('proposes slots that fit the duration inside open windows', () async {
      final controller = AdminAppointmentDetailController(FakeRepository());
      await controller.load('a1');
      await controller.loadAvailability();

      final now = DateTime(2026, 10, 19, 8);
      final days = controller.rescheduleDays(now: now);
      expect(days.first, DateTime(2026, 10, 19));
      expect(days.any((d) => d.weekday == DateTime.sunday), isFalse);

      final times = controller.rescheduleTimes(
        DateTime(2026, 10, 19),
        now: now,
      );
      expect(times.first, DateTime(2026, 10, 19, 10));
      expect(times.last, DateTime(2026, 10, 19, 14));
      expect(
        controller
            .rescheduleTimes(
              DateTime(2026, 10, 19),
              now: DateTime(2026, 10, 19, 11),
            )
            .first,
        DateTime(2026, 10, 19, 11, 30),
      );
    });
  });

  group('AdminAppointmentDetailPage', () {
    Future<(AdminAppointmentDetailController, FakeRepository)> pump(
      WidgetTester tester, {
      AdminAppointmentSyncStatus sync = AdminAppointmentSyncStatus.synced,
      AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
      VoidCallback? onChanged,
    }) async {
      final repository = FakeRepository()
        ..sync = sync
        ..status = status;
      final controller = AdminAppointmentDetailController(repository);
      addTearDown(controller.dispose);
      final router = GoRouter(
        initialLocation: '/admin/appointments/a1',
        routes: [
          GoRoute(
            path: '/admin/appointments',
            builder: (_, _) => const Text('lista'),
          ),
          GoRoute(
            path: '/admin/appointments/:id',
            builder: (_, state) => AdminAppointmentDetailPage(
              controller: controller,
              appointmentId: state.pathParameters['id']!,
              onChanged: onChanged,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(1400, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            disableAnimations: true,
          ),
          child: MaterialApp.router(
            theme: buildInkSlotTheme(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (controller, repository);
    }

    testWidgets('shows the appointment and its actions', (tester) async {
      await pump(tester);
      expect(find.text('ANDRÉS CUEVA'), findsOneWidget);
      expect(find.text('CONFIRMADA'), findsOneWidget);
      expect(find.text('10:00 — 13:00'), findsOneWidget);
      expect(find.text('Google Calendar · Sincronizada'), findsOneWidget);
      expect(find.text('@andres.cv'), findsOneWidget);
      expect(find.text('Reprogramar'), findsOneWidget);
      expect(find.text('Completada'), findsOneWidget);
      expect(find.text('No asistió'), findsOneWidget);
      expect(find.text('Cancelar cita'), findsOneWidget);
    });

    testWidgets('hides actions for closed appointments', (tester) async {
      await pump(tester, status: AdminAppointmentStatus.completed);
      expect(find.text('COMPLETADA'), findsOneWidget);
      expect(find.text('Reprogramar'), findsNothing);
      expect(find.text('Cancelar cita'), findsNothing);
    });

    testWidgets('marks the appointment as completed', (tester) async {
      var changed = 0;
      final (controller, _) = await pump(tester, onChanged: () => changed++);
      await tester.tap(find.text('Completada'));
      await tester.pumpAndSettle();
      expect(controller.detail!.status, AdminAppointmentStatus.completed);
      expect(changed, 1);
      expect(find.text('Cita completada'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('confirms before cancelling', (tester) async {
      final (controller, _) = await pump(tester);
      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cancelar la cita de Andrés?'), findsOneWidget);

      await tester.tap(find.text('Mantener cita'));
      await tester.pumpAndSettle();
      expect(controller.detail!.status, AdminAppointmentStatus.confirmed);

      await tester.tap(find.text('Cancelar cita'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar cita').last);
      await tester.pumpAndSettle();
      expect(controller.detail!.status, AdminAppointmentStatus.cancelled);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('reschedules from the sheet', (tester) async {
      final (controller, repository) = await pump(tester);
      await tester.tap(find.text('Reprogramar'));
      await tester.pumpAndSettle();
      expect(find.text('Mover cita'), findsOneWidget);

      await tester.tap(find.text('Mover cita'));
      await tester.pumpAndSettle();
      expect(repository.rescheduledTo, isNull);

      final label = _hm(
        controller.rescheduleTimes(controller.rescheduleDays().first).first,
      );
      await tester.tap(find.text(label).first);
      await tester.pump();
      await tester.tap(find.text('Mover cita'));
      await tester.pumpAndSettle();
      expect(repository.rescheduledTo, isNotNull);
      expect(find.text('Cita movida · evento actualizado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('retries a failed synchronization', (tester) async {
      final (controller, repository) = await pump(
        tester,
        sync: AdminAppointmentSyncStatus.failed,
      );
      expect(
        find.text('Google Calendar · Error · reintentable'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(repository.retried, isTrue);
      expect(controller.detail!.syncStatus, AdminAppointmentSyncStatus.synced);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

Map<String, dynamic> _detailJson() => {
  'id': 'a1',
  'status': 'confirmed',
  'syncStatus': 'synced',
  'startAt': '2026-10-20T15:00:00.000Z',
  'endAt': '2026-10-20T18:00:00.000Z',
  'version': 1,
  'client': {'name': 'Ana Ink', 'contactValue': '@ana'},
  'durationMinutes': 180,
  'calendarEvent': null,
  'audit': <dynamic>[],
};

Map<String, dynamic> _issue(String id, String appointmentId) => {
  'id': id,
  'appointmentId': appointmentId,
  'operation': 'create',
  'code': 'X',
  'message': 'm',
  'status': 'open',
  'lastAttemptAt': null,
  'createdAt': '2026-10-16T10:00:00.000Z',
};

class RecordingApi implements RestApiClient {
  final List<String> gets = [];
  final List<String> posted = [];
  final List<String> patched = [];
  Map<String, dynamic>? lastBody;
  List<Map<String, dynamic>> issues = [];

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    gets.add(path);
    if (path.startsWith('/admin/sync-issues')) return {'items': issues};
    return _detailJson();
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    posted.add(path);
    lastBody = body;
    return _detailJson();
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    patched.add(path);
    lastBody = body;
    return _detailJson();
  }

  @override
  Future<List<dynamic>> getJsonList(String path) async => [];

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
  }) async => {};

  @override
  Future<void> deleteJson(String path) async {}
}

class FakeRepository extends AdminAppointmentsRepository {
  FakeRepository() : super(RecordingApi());

  AdminAppointmentSyncStatus sync = AdminAppointmentSyncStatus.synced;
  AdminAppointmentStatus status = AdminAppointmentStatus.confirmed;
  bool failAction = false;
  bool retried = false;
  DateTime? rescheduledTo;
  final List<int> versions = [];

  AdminAppointmentDetail _detail({
    AdminAppointmentStatus? status,
    AdminAppointmentSyncStatus? sync,
  }) => AdminAppointmentDetail(
    id: 'a1',
    client: const AdminAppointmentClient(
      name: 'Andrés Cueva',
      contactValue: '@andres.cv',
    ),
    startAt: DateTime(2026, 10, 20, 10).toUtc(),
    endAt: DateTime(2026, 10, 20, 13).toUtc(),
    durationMinutes: 180,
    status: status ?? this.status,
    syncStatus: sync ?? this.sync,
    version: 1,
  );

  @override
  Future<AdminAppointmentDetail> detail(String id) async => _detail();

  @override
  Future<AdminAvailability?> availability() async => AdminAvailability(
    timezone: 'America/Guayaquil',
    slotStepMinutes: 30,
    bufferMinutes: 15,
    minimumNoticeHours: 24,
    horizonDays: 60,
    weeklyWindows: [
      for (final d in [1, 2, 3, 4, 5, 6])
        WeeklyWindow(weekday: d, startLocal: '10:00', endLocal: '17:00'),
    ],
  );

  Future<AdminAppointmentDetail> _act(
    AdminAppointmentStatus next,
    int v,
  ) async {
    versions.add(v);
    if (failAction) {
      throw const ApiException(
        statusCode: 409,
        code: 'SLOT_UNAVAILABLE',
        message: 'El horario ya no está disponible',
      );
    }
    status = next;
    return _detail(status: next);
  }

  @override
  Future<AdminAppointmentDetail> complete(String id, {required int version}) =>
      _act(AdminAppointmentStatus.completed, version);

  @override
  Future<AdminAppointmentDetail> noShow(String id, {required int version}) =>
      _act(AdminAppointmentStatus.noShow, version);

  @override
  Future<AdminAppointmentDetail> cancel(String id, {required int version}) =>
      _act(AdminAppointmentStatus.cancelled, version);

  @override
  Future<AdminAppointmentDetail> reschedule(
    String id, {
    required DateTime startAt,
    required int version,
  }) async {
    rescheduledTo = startAt;
    return _detail();
  }

  @override
  Future<void> retrySync(String id) async {
    retried = true;
    sync = AdminAppointmentSyncStatus.synced;
  }
}
