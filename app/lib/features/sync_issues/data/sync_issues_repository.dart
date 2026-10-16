import '../../../core/network/api_client.dart';
import '../domain/sync_issue.dart';

class SyncIssuesRepository {
  SyncIssuesRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<SyncIssueList> list({
    SyncIssueStatus status = SyncIssueStatus.open,
  }) async {
    final path = Uri(
      path: '/admin/sync-issues',
      queryParameters: <String, String>{'status': status.apiValue},
    ).toString();
    return SyncIssueList.fromJson(await _apiClient.getJson(path));
  }

  Future<void> retry(String id) async {
    await _apiClient.postJson(
      '/admin/sync-issues/${Uri.encodeComponent(id)}/retry',
    );
  }
}
