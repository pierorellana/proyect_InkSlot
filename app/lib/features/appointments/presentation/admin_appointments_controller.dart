import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../data/admin_appointments_repository.dart';
import '../domain/admin_appointment.dart';

enum AdminAppointmentsStatus { idle, loading, loaded, empty, error }

class AdminAppointmentsController extends ChangeNotifier {
  AdminAppointmentsController(this._repository, {this._sessionController});

  final AdminAppointmentsRepository _repository;
  final AdminSessionController? _sessionController;

  AdminAppointmentsStatus _status = AdminAppointmentsStatus.idle;
  AdminAppointmentStatus _filter = AdminAppointmentStatus.confirmed;
  final List<AdminAppointment> _items = <AdminAppointment>[];
  String? _nextCursor;
  String? _errorMessage;
  bool _isLoading = false;
  bool _sessionExpired = false;

  AdminAppointmentsStatus get status => _status;
  AdminAppointmentStatus get filter => _filter;
  List<AdminAppointment> get items => List.unmodifiable(_items);
  String? get nextCursor => _nextCursor;
  String? get errorMessage => _errorMessage;
  bool get sessionExpired => _sessionExpired;

  Future<void> load({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh &&
        (_status == AdminAppointmentsStatus.loaded ||
            _status == AdminAppointmentsStatus.empty)) {
      return;
    }

    if (refresh) {
      _items.clear();
      _nextCursor = null;
    }
    _beginLoading();

    try {
      final page = await _repository.list(status: _filter);
      _replacePage(page);
      _status = _items.isEmpty
          ? AdminAppointmentsStatus.empty
          : AdminAppointmentsStatus.loaded;
      notifyListeners();
    } on Object catch (error) {
      await _fail(error);
    }
  }

  Future<void> setFilter(AdminAppointmentStatus filter) async {
    if (_filter == filter) return;
    _filter = filter;
    await load(refresh: true);
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null || cursor.isEmpty || _isLoading) return;

    _beginLoading();
    try {
      final page = await _repository.list(status: _filter, cursor: cursor);
      _appendPage(page);
      _status = _items.isEmpty
          ? AdminAppointmentsStatus.empty
          : AdminAppointmentsStatus.loaded;
      notifyListeners();
    } on Object catch (error) {
      await _fail(error, keepItems: true);
    }
  }

  void clearError() {
    if (_errorMessage == null && !_sessionExpired) return;
    _errorMessage = null;
    _sessionExpired = false;
    notifyListeners();
  }

  void _beginLoading() {
    _isLoading = true;
    _errorMessage = null;
    _status = AdminAppointmentsStatus.loading;
    notifyListeners();
  }

  void _replacePage(AdminAppointmentPage page) {
    _items
      ..clear()
      ..addAll(page.items);
    _nextCursor = page.nextCursor;
    _isLoading = false;
  }

  void _appendPage(AdminAppointmentPage page) {
    final knownIds = _items.map((item) => item.id).toSet();
    for (final item in page.items) {
      if (knownIds.add(item.id)) _items.add(item);
    }
    _nextCursor = page.nextCursor;
    _isLoading = false;
  }

  Future<void> _fail(Object error, {bool keepItems = false}) async {
    _isLoading = false;
    _errorMessage = _messageFor(error);
    _status = keepItems && _items.isNotEmpty
        ? AdminAppointmentsStatus.loaded
        : AdminAppointmentsStatus.error;
    await _handleSessionExpiry(error);
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'El servidor devolvió datos inválidos.';
    }
    return 'No se pudieron cargar las citas.';
  }

  Future<void> _handleSessionExpiry(Object error) async {
    if (error is! ApiException || !error.isUnauthorized) return;
    _sessionExpired = true;
    if (_sessionController != null) await _sessionController.logout();
  }
}
