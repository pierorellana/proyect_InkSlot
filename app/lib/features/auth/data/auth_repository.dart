import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/admin_user.dart';

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminUser> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.postJson(
      '/auth/login',
      body: <String, dynamic>{'email': email, 'password': password},
    );
    return _parseUser(response);
  }

  Future<AdminUser> currentUser() async {
    final response = await _apiClient.getJson('/auth/me');
    return _parseUser(response);
  }

  Future<void> logout() async {
    await _apiClient.postJson('/auth/logout');
  }

  AdminUser _parseUser(Map<String, dynamic> response) {
    final user = response['user'];
    if (user is! Map) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'El servidor devolvió una respuesta de sesión inválida.',
      );
    }

    return AdminUser.fromJson(Map<String, dynamic>.from(user));
  }
}
