import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/core/network/api_exception.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/auth/data/auth_repository.dart';
import 'package:inkslot_app/features/auth/domain/admin_user.dart';
import 'package:inkslot_app/features/auth/presentation/admin_login_page.dart';
import 'package:inkslot_app/features/auth/presentation/admin_session_controller.dart';

void main() {
  Widget harness(AdminSessionController controller, {VoidCallback? onAuth}) =>
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: AdminLoginPage(
          sessionController: controller,
          onAuthenticated: onAuth,
        ),
      );

  testWidgets('validates the login form before calling the API', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final controller = AdminSessionController(repository);
    await tester.pumpWidget(harness(controller));

    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(repository.loginCalled, isFalse);
  });

  testWidgets('submits credentials and signals a successful session', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final controller = AdminSessionController(repository);
    var authenticated = false;
    await tester.pumpWidget(
      harness(controller, onAuth: () => authenticated = true),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'artist@example.com');
    await tester.enterText(fields.at(1), 'correct-password');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(repository.loginCalled, isTrue);
    expect(repository.lastEmail, 'artist@example.com');
    expect(controller.status, AdminSessionStatus.signedIn);
    expect(authenticated, isTrue);
  });

  testWidgets('shows a safe API error and keeps the form available', (
    tester,
  ) async {
    final repository = FakeAuthRepository(
      loginError: const ApiException(
        statusCode: 401,
        code: 'AUTH_INVALID',
        message: 'Credenciales inválidas',
      ),
    );
    final controller = AdminSessionController(repository);
    await tester.pumpWidget(harness(controller));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'artist@example.com');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.tap(find.text('Entrar'));
    await tester.pump();

    expect(find.text('Credenciales inválidas'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}

class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({this.loginError}) : super(_NoopApiClient());

  final Object? loginError;
  bool loginCalled = false;
  String? lastEmail;

  @override
  Future<AdminUser> login({
    required String email,
    required String password,
  }) async {
    loginCalled = true;
    lastEmail = email;
    if (loginError != null) throw loginError!;
    return const AdminUser(id: 'artist-1', name: 'Gio', role: 'admin');
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
