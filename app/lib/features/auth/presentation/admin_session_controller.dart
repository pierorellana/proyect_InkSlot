import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/admin_user.dart';

enum AdminSessionStatus { checking, signedOut, signedIn, failure }

class AdminSessionController extends ChangeNotifier {
  AdminSessionController(this._authRepository);

  final AuthRepository _authRepository;

  AdminSessionStatus _status = AdminSessionStatus.signedOut;
  AdminUser? _user;
  String? _errorMessage;

  AdminSessionStatus get status => _status;
  AdminUser? get user => _user;
  String? get errorMessage => _errorMessage;

  Future<void> restore() async {
    _setState(AdminSessionStatus.checking, errorMessage: null);

    try {
      final user = await _authRepository.currentUser();
      _user = user;
      _setState(AdminSessionStatus.signedIn);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _user = null;
        _setState(AdminSessionStatus.signedOut);
      } else {
        _fail(error.message);
      }
    } on Object {
      _fail('No se pudo verificar la sesión.');
    }
  }

  Future<void> login(String email, String password) async {
    _user = null;
    _setState(AdminSessionStatus.checking, errorMessage: null);

    try {
      final user = await _authRepository.login(
        email: email.trim(),
        password: password,
      );
      _user = user;
      _setState(AdminSessionStatus.signedIn);
    } on ApiException catch (error) {
      _fail(error.message);
    } on Object {
      _fail('No se pudo iniciar sesión.');
    }
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } on Object {
      // The browser cookie is best-effort. The in-memory session is always
      // forgotten locally so a failed network call cannot keep the UI signed in.
    } finally {
      _user = null;
      _setState(AdminSessionStatus.signedOut, errorMessage: null);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _fail(String message) {
    _user = null;
    _setState(AdminSessionStatus.failure, errorMessage: message);
  }

  void _setState(AdminSessionStatus status, {String? errorMessage}) {
    _status = status;
    _errorMessage = errorMessage;
    notifyListeners();
  }
}
