import '../../../core/network/api_client.dart';
import '../domain/admin_dashboard.dart';

class AdminDashboardRepository {
  AdminDashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminDashboard> load() async {
    final response = await _apiClient.getJson('/admin/dashboard');
    return AdminDashboard.fromJson(response);
  }
}
