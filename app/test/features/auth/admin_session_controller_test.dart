import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/domain/admin_user.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';

void main() {
  test(
    'restores an in-memory session from the current user endpoint',
    () async {
      final repository = FakeAuthRepository(
        currentUserResult: const AdminUser(
          id: 'artist-1',
          name: 'Ink Artist',
          role: 'admin',
        ),
      );
      final controller = AdminSessionController(repository);

      await controller.restore();

      expect(controller.status, AdminSessionStatus.signedIn);
      expect(controller.user?.id, 'artist-1');
      expect(controller.errorMessage, isNull);
    },
  );

  test('turns an expired cookie into a signed-out state', () async {
    final repository = FakeAuthRepository(
      currentUserError: const ApiException(
        statusCode: 401,
        code: 'AUTH_INVALID',
        message: 'Sesión inválida',
      ),
    );
    final controller = AdminSessionController(repository);

    await controller.restore();

    expect(controller.status, AdminSessionStatus.signedOut);
    expect(controller.user, isNull);
    expect(controller.errorMessage, isNull);
  });

  test('exposes safe login failures and does not retain a user', () async {
    final repository = FakeAuthRepository(
      loginError: const ApiException(
        statusCode: 401,
        code: 'AUTH_INVALID',
        message: 'Credenciales inválidas',
      ),
    );
    final controller = AdminSessionController(repository);

    await controller.login('artist@example.test', 'wrong-password');

    expect(controller.status, AdminSessionStatus.failure);
    expect(controller.user, isNull);
    expect(controller.errorMessage, 'Credenciales inválidas');
    expect(repository.lastLoginEmail, 'artist@example.test');
  });

  test('forgets the session in memory when logging out', () async {
    final repository = FakeAuthRepository(
      currentUserResult: const AdminUser(
        id: 'artist-1',
        name: 'Ink Artist',
        role: 'admin',
      ),
    );
    final controller = AdminSessionController(repository);
    await controller.restore();

    await controller.logout();

    expect(controller.status, AdminSessionStatus.signedOut);
    expect(controller.user, isNull);
    expect(repository.logoutCalled, isTrue);
  });
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({
    this.currentUserResult,
    this.currentUserError,
    this.loginResult,
    this.loginError,
  }) : super(_NoopApiClient());

  final AdminUser? currentUserResult;
  final Object? currentUserError;
  final AdminUser? loginResult;
  final Object? loginError;
  String? lastLoginEmail;
  bool logoutCalled = false;

  @override
  Future<AdminUser> currentUser() async {
    if (currentUserError != null) throw currentUserError!;
    return currentUserResult!;
  }

  @override
  Future<AdminUser> login({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    if (loginError != null) throw loginError!;
    return loginResult ??
        const AdminUser(id: 'artist-1', name: 'Ink Artist', role: 'admin');
  }

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
  }) async => <String, dynamic>{};
}
