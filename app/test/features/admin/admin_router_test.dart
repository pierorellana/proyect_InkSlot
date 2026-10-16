import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
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
import 'package:inkslot_app/features/requests/presentation/booking_requests_page.dart';

void main() {
  testWidgets('redirects signed-out admin deep links to login', (tester) async {
    final session = AdminSessionController(FakeAuthRepository());
    final router = AppRouter.create(
      initialLocation: '/admin/requests',
      sessionController: session,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/admin/login');
    expect(find.byType(AdminLoginPage), findsOneWidget);
  });

  testWidgets('routes signed-in users from admin root to requests shell', (
    tester,
  ) async {
    final session = AdminSessionController(FakeAuthRepository());
    await session.login('artist@example.com', 'password');
    final requests = EmptyBookingRequestsController();
    final router = AppRouter.create(
      initialLocation: '/admin',
      sessionController: session,
      bookingRequestsController: requests,
    );
    addTearDown(router.dispose);
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/admin/requests',
    );
    expect(find.byType(AdminShell), findsOneWidget);
    expect(find.byType(BookingRequestsPage), findsOneWidget);
    expect(find.text('Solicitudes'), findsAtLeastNWidgets(1));
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

    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
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

    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
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
    await tester.pumpWidget(
      MaterialApp.router(theme: buildInkSlotTheme(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    expect(find.text('ESPACIO DE TRABAJO'), findsAtLeastNWidgets(2));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.text('Salir'), findsOneWidget);
  });
}

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
  }) async => <String, dynamic>{};
}
