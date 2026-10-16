import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/sync_issues/data/sync_issues_repository.dart';
import 'package:inkslot_app/features/sync_issues/domain/sync_issue.dart';
import 'package:inkslot_app/features/sync_issues/presentation/sync_issues_controller.dart';

void main() {
  test('loads the selected filter and keeps it across refreshes', () async {
    final repository = FakeSyncIssuesRepository(
      results: <SyncIssueList>[
        const SyncIssueList(items: <SyncIssue>[]),
        SyncIssueList(items: <SyncIssue>[_issue('issue-1')]),
      ],
    );
    final controller = SyncIssuesController(repository);

    await controller.load();
    expect(controller.status, SyncIssuesListStatus.empty);

    await controller.setFilter(SyncIssueStatus.resolved);
    expect(controller.filter, SyncIssueStatus.resolved);
    expect(controller.status, SyncIssuesListStatus.loaded);
    expect(repository.filters, [
      SyncIssueStatus.open,
      SyncIssueStatus.resolved,
    ]);
  });

  test('retries one issue and reloads the current filter', () async {
    final repository = FakeSyncIssuesRepository(
      results: <SyncIssueList>[
        SyncIssueList(items: <SyncIssue>[_issue('issue-1')]),
        const SyncIssueList(items: <SyncIssue>[]),
      ],
    );
    final controller = SyncIssuesController(repository);

    await controller.load();
    await controller.retry('issue-1');

    expect(repository.retriedIds, ['issue-1']);
    expect(controller.status, SyncIssuesListStatus.empty);
    expect(controller.retryingId, isNull);
  });
}

class FakeSyncIssuesRepository extends SyncIssuesRepository {
  FakeSyncIssuesRepository({required this.results}) : super(_NoopApiClient());

  final List<SyncIssueList> results;
  final List<SyncIssueStatus> filters = <SyncIssueStatus>[];
  final List<String> retriedIds = <String>[];
  var _index = 0;

  @override
  Future<SyncIssueList> list({
    SyncIssueStatus status = SyncIssueStatus.open,
  }) async {
    filters.add(status);
    return results[_index++];
  }

  @override
  Future<void> retry(String id) async {
    retriedIds.add(id);
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

SyncIssue _issue(String id) => SyncIssue(
  id: id,
  appointmentId: 'appointment-1',
  operation: 'appointment.calendar.update',
  code: 'CALENDAR_UNAVAILABLE',
  message: 'No fue posible sincronizar el evento.',
  status: SyncIssueStatus.open,
  lastAttemptAt: null,
  createdAt: DateTime.utc(2026, 10, 16),
);
