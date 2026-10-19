import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_motion.dart';
import 'package:inkslot_app/features/dashboard/data/admin_dashboard_repository.dart';
import 'package:inkslot_app/features/dashboard/domain/admin_dashboard.dart';
import 'package:inkslot_app/features/dashboard/presentation/admin_dashboard_controller.dart';
import 'package:inkslot_app/features/dashboard/presentation/admin_dashboard_page.dart';

void main() {
  test(
    'calculates remaining hours from the active booking link expiration',
    () {
      final now = DateTime.utc(2026, 10, 19, 12);

      expect(
        remainingBookingLinkHours(DateTime.utc(2026, 10, 20, 12), now: now),
        24,
      );
      expect(
        remainingBookingLinkHours(DateTime.utc(2026, 10, 19, 11), now: now),
        0,
      );
    },
  );

  testWidgets('renders dashboard KPIs and upcoming appointments', (
    tester,
  ) async {
    final controller = AdminDashboardController(
      FakeDashboardRepository(() async => _dashboard()),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(AdminDashboardPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Por agendar  2'), findsOneWidget);
    expect(find.text('Próximas citas'), findsOneWidget);
    expect(find.text('3 citas sin sincronizar'), findsOneWidget);
    expect(find.text('Nueva solicitud'), findsOneWidget);
    expect(find.text('Cliente A'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Calendar: sincronizado',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows a loading state while the dashboard is pending', (
    tester,
  ) async {
    final completer = Completer<AdminDashboard>();
    final controller = AdminDashboardController(
      FakeDashboardRepository(() => completer.future),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(AdminDashboardPage(controller: controller)));
    await tester.pump();

    expect(find.byType(InkSlotPulse), findsOneWidget);
    expect(find.text('Cliente A'), findsNothing);

    completer.complete(_dashboard());
    await tester.pumpAndSettle();
    expect(find.text('Cliente A'), findsOneWidget);
  });

  testWidgets('shows empty upcoming appointments', (tester) async {
    final controller = AdminDashboardController(
      FakeDashboardRepository(
        () async => const AdminDashboard(
          pendingRequests: 1,
          upcomingAppointments: 0,
          syncIssues: 0,
          nextAppointments: [],
        ),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(AdminDashboardPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('No tienes próximas citas.'), findsOneWidget);
    expect(find.textContaining('Por agendar  1'), findsOneWidget);
    expect(find.textContaining('sin sincronizar'), findsNothing);
  });

  testWidgets('shows error and retries the dashboard request', (tester) async {
    var calls = 0;
    final controller = AdminDashboardController(
      FakeDashboardRepository(() async {
        calls++;
        if (calls == 1) {
          throw const ApiException(
            statusCode: 503,
            code: 'SERVICE_UNAVAILABLE',
            message: 'No se pudo cargar el dashboard.',
          );
        }
        return _dashboard();
      }),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_host(AdminDashboardPage(controller: controller)));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo cargar el dashboard.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Cliente A'), findsOneWidget);
  });
}

Widget _host(Widget child) => MaterialApp(
  theme: buildInkSlotTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!,
  ),
  home: Scaffold(body: child),
);

class FakeDashboardRepository extends AdminDashboardRepository {
  FakeDashboardRepository(this.handler) : super(_NoopApiClient());

  final Future<AdminDashboard> Function() handler;

  @override
  Future<AdminDashboard> load() => handler();
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

AdminDashboard _dashboard() => AdminDashboard(
  pendingRequests: 2,
  upcomingAppointments: 1,
  syncIssues: 3,
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
