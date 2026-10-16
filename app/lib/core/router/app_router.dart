import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../features/admin/presentation/admin_requests_placeholder.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/admin_login_page.dart';
import '../../features/auth/presentation/admin_session_controller.dart';
import '../../features/public_booking/presentation/public_dates_placeholder.dart';
import '../../features/public_booking/presentation/public_entry_controller.dart';
import '../../features/public_booking/presentation/public_splash_page.dart';
import '../../features/public_booking/presentation/public_welcome_page.dart';

abstract final class AppRouter {
  static GoRouter create({
    String initialLocation = '/',
    AdminSessionController? sessionController,
  }) {
    final session = sessionController ?? _defaultSessionController();

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
          builder: (context, state) => PublicWelcomePage(
            token: state.pathParameters['token'] ?? '',
            onChooseDate: () =>
                context.go('/r/${state.pathParameters['token'] ?? ''}/dates'),
          ),
        ),
        GoRoute(
          path: '/r/:token/dates',
          builder: (_, _) => const PublicDatesPlaceholder(),
        ),
        GoRoute(
          path: '/admin/login',
          builder: (context, state) => AdminLoginPage(
            sessionController: session,
            onAuthenticated: () => context.go('/admin/requests'),
          ),
        ),
        GoRoute(path: '/admin', redirect: (_, _) => '/admin/requests'),
        ShellRoute(
          builder: (context, state, child) =>
              AdminShell(sessionController: session, child: child),
          routes: [
            GoRoute(
              path: '/admin/requests',
              builder: (_, _) => const AdminRequestsPlaceholder(),
            ),
            GoRoute(
              path: '/admin/requests/new',
              builder: (_, _) => const AdminRequestsPlaceholder(
                title: 'Nueva solicitud',
                description:
                    'El formulario de solicitud estará disponible en el siguiente slice.',
              ),
            ),
            GoRoute(
              path: '/admin/requests/link',
              builder: (_, _) => const AdminRequestsPlaceholder(
                title: 'Enlace listo',
                description:
                    'La entrega segura del enlace estará disponible en el siguiente slice.',
              ),
            ),
            GoRoute(
              path: '/admin/requests/:id',
              builder: (context, state) => AdminRequestsPlaceholder(
                title: 'Detalle de solicitud',
                description:
                    'El detalle de ${state.pathParameters['id'] ?? 'la solicitud'} estará disponible en el siguiente slice.',
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
      AdminSessionStatus.signedIn => isLoginRoute ? '/admin/requests' : null,
      AdminSessionStatus.signedOut ||
      AdminSessionStatus.failure => isLoginRoute ? null : '/admin/login',
    };
  }

  static AdminSessionController _defaultSessionController() =>
      AdminSessionController(AuthRepository(_UnavailableApiClient()));
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
  }) async {
    throw const ApiException(
      code: 'UNAVAILABLE',
      message: 'No hay una sesión administrativa disponible.',
    );
  }
}
