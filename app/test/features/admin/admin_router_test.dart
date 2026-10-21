import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_motion.dart';
import 'package:inkslot_app/features/agenda/presentation/admin_agenda_page.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_controller.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_page.dart';
import 'package:inkslot_app/features/admin/presentation/admin_shell.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/domain/admin_user.dart';
import 'package:inkslot_app/features/auth/presentation/admin_login_page.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_welcome_page.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';
import 'package:inkslot_app/features/requests/presentation/booking_request_detail_page.dart';
import 'package:inkslot_app/features/dashboard/data/admin_dashboard_repository.dart';
import 'package:inkslot_app/features/dashboard/domain/admin_dashboard.dart';
import 'package:inkslot_app/features/dashboard/presentation/admin_dashboard_controller.dart';
import 'package:inkslot_app/features/dashboard/presentation/admin_dashboard_page.dart';
import 'package:inkslot_app/features/sync_issues/data/sync_issues_repository.dart';
import 'package:inkslot_app/features/sync_issues/domain/sync_issue.dart';
import 'package:inkslot_app/features/sync_issues/presentation/sync_issues_controller.dart';
import 'package:inkslot_app/features/sync_issues/presentation/sync_issues_page.dart';

Widget _app(GoRouter router) => MaterialApp.router(
  theme: buildInkSlotTheme(),
  routerConfig: router,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
);

void main() {
  testWidgets('redirects signed-out admin deep links to login', (tester) async {
    final session = AdminSessionController(FakeAuthRepository());
    final router = AppRouter.create(
      initialLocation: '/admin/requests',
      sessionController: session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin/login');
    expect(find.byType(AdminLoginPage), findsOneWidget);
  });

  testWidgets('routes signed-in users from admin root to dashboard shell', (
    tester,
  ) async {
    final session = AdminSessionController(FakeAuthRepository());
    await session.login('artist@example.com', 'password');
    final requests = EmptyBookingRequestsController();
    final dashboard = AdminDashboardController(
      FakeDashboardRepository(() async => _dashboard()),
    );
    final router = AppRouter.create(
      initialLocation: '/admin',
      sessionController: session,
      bookingRequestsController: requests,
      dashboardController: dashboard,
    );
    addTearDown(router.dispose);
    addTearDown(requests.dispose);
    addTearDown(dashboard.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin');
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.byType(AdminDashboardPage), findsOneWidget);
  });

  testWidgets('navigates between admin destinations with stable controllers', (
    tester,
  ) async {
    final session = AdminSessionController(FakeAuthRepository());
    await session.login('artist@example.com', 'password');
    final dashboard = AdminDashboardController(
      FakeDashboardRepository(() async => _dashboard()),
    );
    final appointments = AdminAppointmentsController(
      FakeAppointmentsRepository(),
    );
    final syncIssues = SyncIssuesController(FakeSyncIssuesRepository());
    final router = AppRouter.create(
      initialLocation: '/admin',
      sessionController: session,
      dashboardController: dashboard,
      appointmentsController: appointments,
      syncIssuesController: syncIssues,
    );
    addTearDown(router.dispose);
    addTearDown(dashboard.dispose);
    addTearDown(appointments.dispose);
    addTearDown(syncIssues.dispose);

    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    tester.binding.handleMetricsChanged();
    addTearDown(() {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
    });
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    Future<void> openDrawer() async {
      await tester.tap(_press('Abrir menú'));
      await tester.pumpAndSettle();
    }

    await openDrawer();
    await tester.tap(_press('Citas'));
    await tester.pump();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/admin/appointments',
    );
    expect(find.byType(AdminAppointmentsPage), findsOneWidget);
    await tester.pumpAndSettle();

    await openDrawer();
    await tester.tap(_press('Agenda'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/admin/agenda',
    );
    expect(find.byType(AdminAgendaPage), findsOneWidget);

    await openDrawer();
    await tester.tap(_press('Inicio'));
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin');
    expect(find.byType(AdminDashboardPage), findsOneWidget);

    await openDrawer();
    await tester.tap(_press('Enlaces'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Nueva solicitud'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/admin/requests/new',
    );
    expect(find.text('ENLACES'), findsNothing);

    router.go('/admin/sync-issues');
    await tester.pumpAndSettle();
    expect(find.byType(SyncIssuesPage), findsOneWidget);
  });

  testWidgets('opens sync issues from the dashboard banner', (tester) async {
    final session = AdminSessionController(FakeAuthRepository());
    await session.login('artist@example.com', 'password');
    final dashboard = AdminDashboardController(
      FakeDashboardRepository(() async => _dashboard(syncIssues: 1)),
    );
    final syncIssues = SyncIssuesController(FakeSyncIssuesRepository());
    final router = AppRouter.create(
      initialLocation: '/admin',
      sessionController: session,
      dashboardController: dashboard,
      syncIssuesController: syncIssues,
    );
    addTearDown(router.dispose);
    addTearDown(dashboard.dispose);
    addTearDown(syncIssues.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 cita sin sincronizar'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/admin/sync-issues',
    );
    expect(find.byType(SyncIssuesPage), findsOneWidget);
  });

  testWidgets('keeps public deep links outside the admin guard', (
    tester,
  ) async {
    final session = AdminSessionController(FakeAuthRepository());
    final router = AppRouter.create(
      initialLocation: '/r/private-token',
      sessionController: session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pump();

    expect(find.byType(PublicWelcomePage), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/r/private-token',
    );
  });

  testWidgets('routes request detail inside the protected admin shell', (
    tester,
  ) async {
    final session = AdminSessionController(FakeAuthRepository());
    await session.login('artist@example.com', 'password');
    final requests = EmptyBookingRequestsController();
    final router = AppRouter.create(
      initialLocation: '/admin/requests/request-1',
      sessionController: session,
      bookingRequestsController: requests,
    );
    addTearDown(router.dispose);
    addTearDown(requests.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();

    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.byType(BookingRequestDetailPage), findsOneWidget);
  });

  testWidgets('switches between desktop rail and mobile navigation', (
    tester,
  ) async {
    final session = AdminSessionController(FakeAuthRepository());
    await session.login('artist@example.com', 'password');
    final router = AppRouter.create(
      initialLocation: '/admin/requests',
      sessionController: session,
    );
    addTearDown(router.dispose);

    tester.view
      ..physicalSize = const Size(1200, 800)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..physicalSize = const Size(800, 600)
        ..devicePixelRatio = 1;
    });
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar sesión'), findsOneWidget);
    expect(_press('Abrir menú'), findsNothing);

    tester.view.physicalSize = const Size(768, 900);
    tester.binding.handleMetricsChanged();
    await tester.pumpAndSettle();
    expect(_press('Abrir menú'), findsNothing);
    expect(_press('Inicio'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);
    await tester.tap(_press('Enlaces'));
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/admin/requests',
    );

    tester.view.physicalSize = const Size(390, 844);
    tester.binding.handleMetricsChanged();
    await tester.pumpAndSettle();
    expect(_press('Abrir menú'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);

    await tester.tap(_press('Abrir menú'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Enlaces'), findsOneWidget);
  });
}

Finder _press(String label) => find.byWidgetPredicate(
  (widget) => widget is InkSlotPress && widget.semanticLabel == label,
);

class EmptyBookingRequestsController extends BookingRequestsController {
  EmptyBookingRequestsController() : super(EmptyBookingRequestsRepository());
}

class EmptyBookingRequestsRepository extends BookingRequestsRepository {
  EmptyBookingRequestsRepository() : super(_NoopApiClient());

  @override
  Future<BookingRequestPage> list({
    BookingRequestStatus? status,
    String? cursor,
  }) async => const BookingRequestPage(items: [], nextCursor: null);
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository() : super(_NoopApiClient());

  @override
  Future<AdminUser> login({
    required String email,
    required String password,
  }) async => const AdminUser(id: 'artist-1', name: 'Gio', role: 'admin');
}

class FakeDashboardRepository extends AdminDashboardRepository {
  FakeDashboardRepository(this.handler) : super(_NoopApiClient());

  final Future<AdminDashboard> Function() handler;

  @override
  Future<AdminDashboard> load() => handler();
}

class FakeAppointmentsRepository extends AdminAppointmentsRepository {
  FakeAppointmentsRepository() : super(_NoopApiClient());

  @override
  Future<AdminAppointmentPage> list({
    AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
    String? cursor,
  }) async => const AdminAppointmentPage(items: [], nextCursor: null);
}

class FakeSyncIssuesRepository extends SyncIssuesRepository {
  FakeSyncIssuesRepository() : super(_NoopApiClient());

  @override
  Future<SyncIssueList> list({
    SyncIssueStatus status = SyncIssueStatus.open,
  }) async => const SyncIssueList(items: []);
}

class _NoopApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    throw const ApiException(
      statusCode: 401,
      code: 'AUTH_INVALID',
      message: 'Sesión inválida',
    );
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => <String, dynamic>{};
}

AdminDashboard _dashboard({int syncIssues = 0}) => AdminDashboard(
  pendingRequests: 2,
  upcomingAppointments: 1,
  syncIssues: syncIssues,
  nextAppointments: [
    DashboardAppointment(
      id: 'appointment-a',
      client: const DashboardClient(name: 'Cliente A'),
      startAt: DateTime.utc(2026, 10, 20, 15),
      endAt: DateTime.utc(2026, 10, 20, 18),
      durationMinutes: 180,
      status: 'confirmed',
      syncStatus: 'synced',
    ),
  ],
);
