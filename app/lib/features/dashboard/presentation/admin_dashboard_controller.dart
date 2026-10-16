import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../data/admin_dashboard_repository.dart';
import '../domain/admin_dashboard.dart';

enum AdminDashboardStatus { idle, loading, loaded, empty, error }

class AdminDashboardController extends ChangeNotifier {
  AdminDashboardController(this._repository, {this._sessionController});

  final AdminDashboardRepository _repository;
  final AdminSessionController? _sessionController;

  AdminDashboardStatus _status = AdminDashboardStatus.idle;
  AdminDashboard? _dashboard;
  String? _errorMessage;
  bool _sessionExpired = false;

  AdminDashboardStatus get status => _status;
  AdminDashboard? get dashboard => _dashboard;
  String? get errorMessage => _errorMessage;
  bool get sessionExpired => _sessionExpired;

  Future<void> load({bool refresh = false}) async {
    if (_status == AdminDashboardStatus.loading) return;
    if (!refresh &&
        _dashboard != null &&
        (_status == AdminDashboardStatus.loaded ||
            _status == AdminDashboardStatus.empty)) {
      return;
    }

    _errorMessage = null;
    _sessionExpired = false;
    _status = AdminDashboardStatus.loading;
    notifyListeners();

    try {
      final dashboard = await _repository.load();
      _dashboard = dashboard;
      _status = dashboard.nextAppointments.isEmpty
          ? AdminDashboardStatus.empty
          : AdminDashboardStatus.loaded;
      notifyListeners();
    } on Object catch (error) {
      _status = AdminDashboardStatus.error;
      _errorMessage = _messageFor(error);
      await _handleSessionExpiry(error);
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null && !_sessionExpired) return;

    _errorMessage = null;
    _sessionExpired = false;
    _status = switch (_dashboard) {
      null => AdminDashboardStatus.idle,
      final dashboard when dashboard.nextAppointments.isEmpty =>
        AdminDashboardStatus.empty,
      _ => AdminDashboardStatus.loaded,
    };
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'El servidor devolvió datos inválidos.';
    }
    return 'No se pudo cargar el dashboard.';
  }

  Future<void> _handleSessionExpiry(Object error) async {
    if (error is! ApiException || !error.isUnauthorized) return;

    _sessionExpired = true;
    if (_sessionController != null) {
      await _sessionController.logout();
    }
  }
}
