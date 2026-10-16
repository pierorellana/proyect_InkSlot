import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/dashboard/data/admin_dashboard_repository.dart';

void main() {
  test('loads and parses the dashboard projection', () async {
    final client = RecordingApiClient(_dashboardJson());
    final repository = AdminDashboardRepository(client);

    final dashboard = await repository.load();

    expect(dashboard.pendingRequests, 2);
    expect(dashboard.upcomingAppointments, 1);
    expect(dashboard.syncIssues, 0);
    expect(dashboard.nextAppointments, hasLength(1));
    expect(dashboard.nextAppointments.single.client.name, 'Cliente A');
    expect(client.lastGetPath, '/admin/dashboard');
  });

  test('rejects non-integer counters', () async {
    final repository = AdminDashboardRepository(
      RecordingApiClient({..._dashboardJson(), 'pendingRequests': 2.0}),
    );

    await expectLater(repository.load(), throwsA(isA<FormatException>()));
  });

  test('rejects invalid appointment lists', () async {
    final repository = AdminDashboardRepository(
      RecordingApiClient({
        ..._dashboardJson(),
        'nextAppointments': ['invalid'],
      }),
    );

    await expectLater(repository.load(), throwsA(isA<FormatException>()));
  });

  test('rejects non-ISO appointment dates', () async {
    final appointment = Map<String, dynamic>.from(
      (_dashboardJson()['nextAppointments'] as List).single as Map,
    )..['startAt'] = '2026-10-20';
    final repository = AdminDashboardRepository(
      RecordingApiClient({
        ..._dashboardJson(),
        'nextAppointments': [appointment],
      }),
    );

    await expectLater(repository.load(), throwsA(isA<FormatException>()));
  });

  test('rejects unknown appointment sync states', () async {
    final appointment = Map<String, dynamic>.from(
      (_dashboardJson()['nextAppointments'] as List).single as Map,
    )..['syncStatus'] = 'provider_down';
    final repository = AdminDashboardRepository(
      RecordingApiClient({
        ..._dashboardJson(),
        'nextAppointments': [appointment],
      }),
    );

    await expectLater(repository.load(), throwsA(isA<FormatException>()));
  });
}

class RecordingApiClient implements ApiClient {
  RecordingApiClient(this.response);

  final Map<String, dynamic> response;
  String? lastGetPath;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    lastGetPath = path;
    return response;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => <String, dynamic>{};
}

Map<String, dynamic> _dashboardJson() => <String, dynamic>{
  'pendingRequests': 2,
  'upcomingAppointments': 1,
  'syncIssues': 0,
  'nextAppointments': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'appointment-a',
      'client': <String, dynamic>{'name': 'Cliente A'},
      'startAt': '2026-10-20T15:00:00.000Z',
      'endAt': '2026-10-20T18:00:00.000Z',
      'durationMinutes': 180,
      'status': 'confirmed',
      'syncStatus': 'synced',
    },
  ],
};
