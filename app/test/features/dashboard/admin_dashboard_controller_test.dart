import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';
import 'package:inkslot_app/features/dashboard/data/admin_dashboard_repository.dart';
import 'package:inkslot_app/features/dashboard/domain/admin_dashboard.dart';
import 'package:inkslot_app/features/dashboard/presentation/admin_dashboard_controller.dart';

void main() {
  test('transitions from idle to loading and loaded', () async {
    final expected = _dashboard();
    final controller = AdminDashboardController(
      FakeDashboardRepository([expected]),
    );
    final statuses = <AdminDashboardStatus>[];
    controller.addListener(() => statuses.add(controller.status));

    await controller.load();

    expect(statuses, [
      AdminDashboardStatus.loading,
      AdminDashboardStatus.loaded,
    ]);
    expect(controller.dashboard, same(expected));
    expect(controller.errorMessage, isNull);
  });

  test('uses empty without discarding valid counters', () async {
    final empty = AdminDashboard(
      pendingRequests: 3,
      upcomingAppointments: 0,
      syncIssues: 1,
      nextAppointments: const [],
    );
    final controller = AdminDashboardController(
      FakeDashboardRepository([empty]),
    );

    await controller.load();

    expect(controller.status, AdminDashboardStatus.empty);
    expect(controller.dashboard?.pendingRequests, 3);
    expect(controller.dashboard?.syncIssues, 1);
  });

  test('preserves the previous dashboard during a failed retry', () async {
    final previous = _dashboard();
    final controller = AdminDashboardController(
      FakeDashboardRepository([
        previous,
        const ApiException(
          statusCode: 503,
          code: 'SERVICE_UNAVAILABLE',
          message: 'Servicio no disponible',
        ),
      ]),
    );

    await controller.load();
    await controller.load(refresh: true);

    expect(controller.status, AdminDashboardStatus.error);
    expect(controller.dashboard, same(previous));
    expect(controller.errorMessage, 'Servicio no disponible');
  });

  test('returns a safe message for invalid server data', () async {
    final controller = AdminDashboardController(
      FakeDashboardRepository([const FormatException('secret payload')]),
    );

    await controller.load();

    expect(controller.status, AdminDashboardStatus.error);
    expect(controller.errorMessage, 'El servidor devolvió datos inválidos.');
    expect(controller.errorMessage, isNot(contains('secret')));
  });

  test('marks session expiry and logs out when the API returns 401', () async {
    final session = RecordingSessionController();
    final controller = AdminDashboardController(
      FakeDashboardRepository([
        const ApiException(
          statusCode: 401,
          code: 'AUTH_INVALID',
          message: 'La sesión no es válida.',
        ),
      ]),
      sessionController: session,
    );

    await controller.load();

    expect(controller.status, AdminDashboardStatus.error);
    expect(controller.sessionExpired, isTrue);
    expect(session.logoutCalled, isTrue);
  });
}

class FakeDashboardRepository extends AdminDashboardRepository {
  FakeDashboardRepository(this.outcomes) : super(_NoopApiClient());

  final List<Object> outcomes;
  var _calls = 0;

  @override
  Future<AdminDashboard> load() async {
    final outcome = outcomes[_calls++];
    if (outcome is AdminDashboard) return outcome;
    throw outcome;
  }
}

class RecordingSessionController extends AdminSessionController {
  RecordingSessionController() : super(AuthRepository(_NoopApiClient()));

  var logoutCalled = false;

  @override
  Future<void> logout() async {
    logoutCalled = true;
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

AdminDashboard _dashboard() => AdminDashboard(
  pendingRequests: 2,
  upcomingAppointments: 1,
  syncIssues: 0,
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
