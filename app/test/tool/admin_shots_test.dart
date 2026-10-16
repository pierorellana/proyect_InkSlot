import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_kit.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/domain/admin_user.dart';
import 'package:inkslot_app/features/auth/presentation/admin_login_page.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';
import 'package:inkslot_app/features/dashboard/data/admin_dashboard_repository.dart';
import 'package:inkslot_app/features/dashboard/domain/admin_dashboard.dart';
import 'package:inkslot_app/features/dashboard/presentation/admin_dashboard_controller.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';
import 'package:inkslot_app/features/requests/presentation/link_ready_page.dart';
import 'package:inkslot_app/features/sync_issues/data/sync_issues_repository.dart';
import 'package:inkslot_app/features/sync_issues/domain/sync_issue.dart';
import 'package:inkslot_app/features/sync_issues/presentation/sync_issues_controller.dart';

import 'shot_helper.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('login', (t) async {
    final session = AdminSessionController(_Auth());
    await shot(
      t,
      'a20-login',
      AdminLoginPage(sessionController: session),
      settle: const Duration(milliseconds: 2500),
    );
  });

  testWidgets('login-error', (t) async {
    final session = AdminSessionController(_Auth());
    await shot(
      t,
      'a21-login-error',
      AdminLoginPage(sessionController: session),
      settle: const Duration(milliseconds: 2500),
      after: (t) async {
        await t.tap(find.text('Entrar'));
        await t.pump(const Duration(milliseconds: 600));
      },
    );
  });

  testWidgets('inicio', (t) async {
    final session = AdminSessionController(_Auth());
    await session.login('gio@dodogio.studio', 'x');
    final home = _router(session, '/admin');
    await shot(
      t,
      'a22-inicio',
      _app(home),
      settle: const Duration(milliseconds: 2500),
    );
  });

  testWidgets('inicio-sin-incidencias', (t) async {
    final session = AdminSessionController(_Auth());
    await session.login('gio@dodogio.studio', 'x');
    final home = _router(session, '/admin', syncIssues: 0);
    await shot(
      t,
      'a24-inicio-ok',
      _app(home),
      settle: const Duration(milliseconds: 2500),
    );
  });

  testWidgets('incidencias', (t) async {
    final session = AdminSessionController(_Auth());
    await session.login('gio@dodogio.studio', 'x');
    final home = _router(session, '/admin/sync-issues');
    await shot(
      t,
      'a23-incidencias',
      _app(home),
      settle: const Duration(milliseconds: 2500),
    );
  });

  testWidgets('nueva', (t) async {
    final session = AdminSessionController(_Auth());
    await session.login('gio@dodogio.studio', 'x');
    final home = _router(session, '/admin/requests/new');
    await shot(
      t,
      'a25-nueva',
      _app(home),
      settle: const Duration(milliseconds: 1500),
    );
  });

  testWidgets('nueva-completa', (t) async {
    final session = AdminSessionController(_Auth());
    await session.login('gio@dodogio.studio', 'x');
    final home = _router(session, '/admin/requests/new');
    await shot(
      t,
      'a26-nueva-completa',
      _app(home),
      settle: const Duration(milliseconds: 1500),
      after: (t) async {
        await t.enterText(find.byType(TextField).at(0), 'Daniela Mora');
        await t.enterText(find.byType(TextField).at(1), '+593 99 123 4567');
        await t.tap(find.byType(InkSlotSwitch).at(0));
        await t.pump(const Duration(milliseconds: 500));
        await t.ensureVisible(find.byType(InkSlotSwitch).at(1));
        await t.tap(find.byType(InkSlotSwitch).at(1));
        await t.pump(const Duration(milliseconds: 1200));
        await t.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -260),
        );
        await t.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('enlace', (t) async {
    await shot(
      t,
      'a27-enlace',
      Scaffold(
        body: LinkReadyPage(
          link: LinkReadyData(
            path: '/r/q2xvK8mTz4wtq',
            expiresAt: DateTime.now().add(const Duration(hours: 48)),
          ),
          clientName: 'Daniela Mora',
          durationMinutes: 180,
        ),
      ),
      settle: const Duration(milliseconds: 2500),
    );
  });

  testWidgets('compartir', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await shot(
      t,
      'a29-compartir',
      Scaffold(
        body: LinkReadyPage(
          link: LinkReadyData(
            path: '/r/q2xvK8mTz4wtq',
            expiresAt: DateTime.now().add(const Duration(hours: 48)),
          ),
          clientName: 'Daniela Mora',
          durationMinutes: 180,
        ),
      ),
      settle: const Duration(milliseconds: 2500),
      after: (t) async {
        await t.tap(find.text('Copiar enlace'));
        await t.pump(const Duration(milliseconds: 600));
        await t.tap(find.text('Compartir'));
        await t.pump(const Duration(milliseconds: 1000));
      },
    );
    await t.pump(const Duration(seconds: 4));
  });
}

Widget _app(GoRouter router) => MaterialApp.router(
  debugShowCheckedModeBanner: false,
  theme: buildInkSlotTheme(),
  routerConfig: router,
);

GoRouter _router(
  AdminSessionController session,
  String location, {
  int syncIssues = 1,
}) {
  final dashboard = AdminDashboardController(_DashRepo(syncIssues));
  final requests = BookingRequestsController(_ReqRepo());
  final sync = SyncIssuesController(_SyncRepo());
  return AppRouter.create(
    initialLocation: location,
    sessionController: session,
    dashboardController: dashboard,
    bookingRequestsController: requests,
    syncIssuesController: sync,
  );
}

class _Auth extends AuthRepository {
  _Auth() : super(_Noop());
  @override
  Future<AdminUser> login({
    required String email,
    required String password,
  }) async => const AdminUser(id: 'a', name: 'Gio', role: 'admin');
}

class _DashRepo extends AdminDashboardRepository {
  _DashRepo(this.syncIssues) : super(_Noop());
  final int syncIssues;
  @override
  Future<AdminDashboard> load() async {
    DateTime at(int d, int h, int m) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day + d, h, m);
    }

    DashboardAppointment a(String n, DateTime s, int mins, String sync) =>
        DashboardAppointment(
          id: n,
          client: DashboardClient(name: n),
          startAt: s,
          endAt: s.add(Duration(minutes: mins)),
          durationMinutes: mins,
          status: 'confirmed',
          syncStatus: sync,
        );
    return AdminDashboard(
      pendingRequests: 2,
      upcomingAppointments: 3,
      syncIssues: syncIssues,
      nextAppointments: [
        a('Joaquín Vera', at(1, 11, 0), 90, 'synced'),
        a(
          'Sofía Paredes',
          at(2, 14, 30),
          240,
          syncIssues > 0 ? 'failed' : 'synced',
        ),
        a('Andrés Cueva', at(5, 10, 0), 180, 'synced'),
      ],
    );
  }
}

class _ReqRepo extends BookingRequestsRepository {
  _ReqRepo() : super(_Noop());
  @override
  Future<BookingRequestPage> list({
    BookingRequestStatus? status,
    String? cursor,
  }) async {
    BookingRequest r(
      String id,
      String n,
      ContactChannel c,
      int mins,
      int ago,
    ) => BookingRequest(
      id: id,
      client: BookingRequestClient(id: id, name: n, contactChannel: c),
      paymentReference: null,
      depositVerified: true,
      durationMinutes: mins,
      status: BookingRequestStatus.pending,
      minDate: null,
      maxDate: null,
      allowedWeekdays: null,
      allowedWindows: null,
      createdAt: DateTime.now().subtract(Duration(hours: ago)),
    );
    return BookingRequestPage(
      items: [
        r('1', 'Valentina Rosero', ContactChannel.whatsapp, 180, 1),
        r('2', 'Mateo Andrade', ContactChannel.instagram, 120, 39),
      ],
      nextCursor: null,
    );
  }
}

class _SyncRepo extends SyncIssuesRepository {
  _SyncRepo() : super(_Noop());
  @override
  Future<SyncIssueList> list({
    SyncIssueStatus status = SyncIssueStatus.open,
  }) async => SyncIssueList(
    items: [
      SyncIssue(
        id: 'i1',
        appointmentId: 'a1',
        operation: 'appointment.calendar.create',
        code: 'CALENDAR_TIMEOUT',
        message: 'Error al crear evento (tiempo de espera)',
        status: status,
        lastAttemptAt: null,
        createdAt: DateTime.now(),
      ),
    ],
  );
}

class _Noop implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async => {};
  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => {};
}
