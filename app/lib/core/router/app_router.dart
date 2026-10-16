import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/agenda/data/agenda_repository.dart';
import '../../features/agenda/presentation/admin_agenda_page.dart';
import '../../features/agenda/presentation/agenda_controller.dart';
import '../../features/appointments/data/admin_appointments_repository.dart';
import '../../features/appointments/presentation/admin_appointment_detail_controller.dart';
import '../../features/appointments/presentation/admin_appointment_detail_page.dart';
import '../../features/appointments/presentation/admin_appointments_controller.dart';
import '../../features/appointments/presentation/admin_appointments_page.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/admin_login_page.dart';
import '../../features/auth/presentation/admin_session_controller.dart';
import '../../features/dashboard/data/admin_dashboard_repository.dart';
import '../../features/dashboard/presentation/admin_dashboard_controller.dart';
import '../../features/dashboard/presentation/admin_dashboard_page.dart';
import '../../features/public_booking/data/public_reservation_repository.dart';
import '../../features/public_booking/presentation/public_entry_controller.dart';
import '../../features/public_booking/presentation/public_dates_page.dart';
import '../../features/public_booking/presentation/public_reservation_controller.dart';
import '../../features/public_booking/presentation/public_result_page.dart';
import '../../features/public_booking/presentation/public_review_page.dart';
import '../../features/public_booking/presentation/public_splash_page.dart';
import '../../features/public_booking/presentation/public_welcome_page.dart';
import '../../features/requests/data/booking_requests_repository.dart';
import '../../features/requests/domain/booking_request.dart';
import '../../features/requests/presentation/booking_requests_controller.dart';
import '../../features/requests/presentation/booking_request_detail_page.dart';
import '../../features/requests/presentation/booking_requests_page.dart';
import '../../features/requests/presentation/link_ready_page.dart';
import '../../features/requests/presentation/new_booking_request_page.dart';
import '../../features/sync_issues/data/sync_issues_repository.dart';
import '../../features/sync_issues/presentation/sync_issues_controller.dart';
import '../../features/sync_issues/presentation/sync_issues_page.dart';

abstract final class AppRouter {
  static GoRouter create({
    String initialLocation = '/',
    AdminSessionController? sessionController,
    BookingRequestsController? bookingRequestsController,
    AdminDashboardController? dashboardController,
    AdminAppointmentsController? appointmentsController,
    AdminAppointmentDetailController? appointmentDetailController,
    AgendaController? agendaController,
    SyncIssuesController? syncIssuesController,
    PublicReservationController? publicReservationController,
    ApiClient? apiClient,
  }) {
    final session = sessionController ?? _defaultSessionController(apiClient);
    final requests =
        bookingRequestsController ??
        _defaultBookingRequestsController(session, apiClient);
    final dashboard =
        dashboardController ?? _defaultDashboardController(session, apiClient);
    final appointments =
        appointmentsController ??
        _defaultAppointmentsController(session, apiClient);
    final appointmentDetail =
        appointmentDetailController ??
        _defaultAppointmentDetailController(session, apiClient);
    final agenda =
        agendaController ?? _defaultAgendaController(session, apiClient);
    final syncIssues =
        syncIssuesController ??
        _defaultSyncIssuesController(session, apiClient);
    final publicReservation =
        publicReservationController ??
        _defaultPublicReservationController(apiClient);

    return GoRouter(
      initialLocation: initialLocation,
      refreshListenable: session,
      redirect: (context, state) => _redirect(session, state),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            final router = GoRouter.of(context);
            return ChangeNotifierProvider(
              create: (_) => PublicEntryController(),
              child: PublicSplashPage(
                onFinished: () => router.go('/r/demo-token'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/r/:token',
          builder: (context, state) => ChangeNotifierProvider.value(
            value: publicReservation,
            child: PublicWelcomePage(
              controller: publicReservation,
              token: state.pathParameters['token'] ?? '',
              onChooseDate: () => context.go(
                _publicPath(state.pathParameters['token'] ?? '', 'dates'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/r/:token/dates',
          builder: (context, state) => ChangeNotifierProvider.value(
            value: publicReservation,
            child: PublicDatesPage(
              controller: publicReservation,
              token: state.pathParameters['token'] ?? '',
              onReview: () => context.go(
                _publicPath(state.pathParameters['token'] ?? '', 'review'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/r/:token/review',
          builder: (context, state) => ChangeNotifierProvider.value(
            value: publicReservation,
            child: PublicReviewPage(
              controller: publicReservation,
              token: state.pathParameters['token'] ?? '',
              onBack: () => context.go(
                _publicPath(state.pathParameters['token'] ?? '', 'dates'),
              ),
              onConfirmed: () => context.go(
                _publicPath(state.pathParameters['token'] ?? '', 'result'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/r/:token/result',
          builder: (context, state) => ChangeNotifierProvider.value(
            value: publicReservation,
            child: PublicResultPage(
              controller: publicReservation,
              token: state.pathParameters['token'] ?? '',
              onReturnToDates: () => context.go(
                _publicPath(state.pathParameters['token'] ?? '', 'dates'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/admin/login',
          builder: (context, state) => AdminLoginPage(
            sessionController: session,
            onAuthenticated: () => context.go('/admin'),
          ),
        ),
        ShellRoute(
          builder: (context, state, child) =>
              AdminShell(sessionController: session, child: child),
          routes: [
            GoRoute(
              path: '/admin',
              builder: (_, _) => ChangeNotifierProvider.value(
                value: dashboard,
                child: AdminDashboardPage(
                  controller: dashboard,
                  sessionController: session,
                  requestsController: requests,
                ),
              ),
            ),
            GoRoute(
              path: '/admin/requests',
              builder: (_, _) => ChangeNotifierProvider.value(
                value: requests,
                child: BookingRequestsPage(controller: requests),
              ),
            ),
            GoRoute(
              path: '/admin/requests/new',
              builder: (context, state) => ChangeNotifierProvider.value(
                value: requests,
                child: NewBookingRequestPage(controller: requests),
              ),
            ),
            GoRoute(
              path: '/admin/requests/link',
              redirect: (_, state) =>
                  state.extra is LinkReadyData || state.extra is LinkReadyArgs
                  ? null
                  : '/admin/requests',
              builder: (context, state) {
                final extra = state.extra;
                final args = extra is LinkReadyArgs
                    ? extra
                    : LinkReadyArgs(link: extra! as LinkReadyData);
                return LinkReadyPage(
                  link: args.link,
                  clientName: args.clientName,
                  durationMinutes: args.durationMinutes,
                  onBack: () => context.go('/admin'),
                );
              },
            ),
            GoRoute(
              path: '/admin/requests/:id',
              builder: (_, state) => ChangeNotifierProvider.value(
                value: requests,
                child: BookingRequestDetailPage(
                  controller: requests,
                  requestId: state.pathParameters['id'] ?? '',
                ),
              ),
            ),
            GoRoute(
              path: '/admin/appointments',
              builder: (_, _) => ChangeNotifierProvider.value(
                value: appointments,
                child: AdminAppointmentsPage(controller: appointments),
              ),
            ),
            GoRoute(
              path: '/admin/appointments/:id',
              builder: (_, state) => AdminAppointmentDetailPage(
                controller: appointmentDetail,
                appointmentId: state.pathParameters['id'] ?? '',
                onChanged: () => appointments.load(refresh: true),
              ),
            ),
            GoRoute(
              path: '/admin/agenda',
              builder: (_, _) => AdminAgendaPage(controller: agenda),
            ),
            GoRoute(
              path: '/admin/sync-issues',
              builder: (_, _) => ChangeNotifierProvider.value(
                value: syncIssues,
                child: SyncIssuesPage(controller: syncIssues),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String? _redirect(
    AdminSessionController session,
    GoRouterState state,
  ) {
    final path = state.uri.path;
    final isAdminRoute = path == '/admin' || path.startsWith('/admin/');
    if (!isAdminRoute) return null;

    final isLoginRoute = path == '/admin/login';
    return switch (session.status) {
      AdminSessionStatus.checking => null,
      AdminSessionStatus.signedIn => isLoginRoute ? '/admin' : null,
      AdminSessionStatus.signedOut ||
      AdminSessionStatus.failure => isLoginRoute ? null : '/admin/login',
    };
  }

  static String _publicPath(String token, String page) =>
      '/r/${Uri.encodeComponent(token)}/$page';

  static AdminSessionController _defaultSessionController(
    ApiClient? apiClient,
  ) => AdminSessionController(
    AuthRepository(apiClient ?? _UnavailableApiClient()),
  );

  static BookingRequestsController _defaultBookingRequestsController(
    AdminSessionController session,
    ApiClient? apiClient,
  ) => BookingRequestsController(
    BookingRequestsRepository(apiClient ?? _UnavailableApiClient()),
    sessionController: session,
  );

  static AdminDashboardController _defaultDashboardController(
    AdminSessionController session,
    ApiClient? apiClient,
  ) => AdminDashboardController(
    AdminDashboardRepository(apiClient ?? _UnavailableApiClient()),
    sessionController: session,
  );

  static AdminAppointmentsController _defaultAppointmentsController(
    AdminSessionController session,
    ApiClient? apiClient,
  ) => AdminAppointmentsController(
    AdminAppointmentsRepository(apiClient ?? _UnavailableApiClient()),
    sessionController: session,
  );

  static AdminAppointmentDetailController _defaultAppointmentDetailController(
    AdminSessionController session,
    ApiClient? apiClient,
  ) => AdminAppointmentDetailController(
    AdminAppointmentsRepository(apiClient ?? _UnavailableApiClient()),
    sessionController: session,
  );

  static AgendaController _defaultAgendaController(
    AdminSessionController session,
    ApiClient? apiClient,
  ) => AgendaController(
    AgendaRepository(apiClient ?? _UnavailableApiClient()),
    sessionController: session,
  );

  static SyncIssuesController _defaultSyncIssuesController(
    AdminSessionController session,
    ApiClient? apiClient,
  ) => SyncIssuesController(
    SyncIssuesRepository(apiClient ?? _UnavailableApiClient()),
    sessionController: session,
  );

  static PublicReservationController _defaultPublicReservationController(
    ApiClient? apiClient,
  ) => PublicReservationController(
    PublicReservationRepository(apiClient ?? _UnavailableApiClient()),
  );
}

class _UnavailableApiClient implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    throw const ApiException(
      code: 'UNAVAILABLE',
      message: 'No hay una sesión administrativa disponible.',
    );
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    throw const ApiException(
      code: 'UNAVAILABLE',
      message: 'No hay una sesión administrativa disponible.',
    );
  }
}
