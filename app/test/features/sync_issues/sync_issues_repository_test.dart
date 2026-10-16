import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/sync_issues/data/sync_issues_repository.dart';
import 'package:inkslot_app/features/sync_issues/domain/sync_issue.dart';

void main() {
  test('maps status filter and parses nullable attempt dates', () async {
    final api = RecordingApiClient(
      getResult: <String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'issue-1',
            'appointmentId': 'appointment-1',
            'operation': 'appointment.calendar.update',
            'code': 'CALENDAR_UNAVAILABLE',
            'message': 'No fue posible sincronizar el evento.',
            'status': 'open',
            'lastAttemptAt': null,
            'createdAt': '2026-10-16T10:00:00.000Z',
          },
        ],
      },
    );

    final result = await SyncIssuesRepository(
      api,
    ).list(status: SyncIssueStatus.open);

    expect(api.lastGetPath, '/admin/sync-issues?status=open');
    expect(result.items.single.lastAttemptAt, isNull);
    expect(result.items.single.code, 'CALENDAR_UNAVAILABLE');
  });

  test('maps retry endpoint with an encoded issue id', () async {
    final api = RecordingApiClient(
      getResult: <String, dynamic>{'items': <dynamic>[]},
    );

    await SyncIssuesRepository(api).retry('issue/1');

    expect(api.lastPostPath, '/admin/sync-issues/issue%2F1/retry');
  });
}

class RecordingApiClient implements ApiClient {
  RecordingApiClient({required this.getResult});

  final Map<String, dynamic> getResult;
  String? lastGetPath;
  String? lastPostPath;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    lastGetPath = path;
    return getResult;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    lastPostPath = path;
    return <String, dynamic>{'status': 'queued'};
  }
}
