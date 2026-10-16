import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../data/sync_issues_repository.dart';
import '../domain/sync_issue.dart';

enum SyncIssuesListStatus { idle, loading, loaded, empty, error }

class SyncIssuesController extends ChangeNotifier {
  SyncIssuesController(this._repository, {this.sessionController});

  final SyncIssuesRepository _repository;
  final AdminSessionController? sessionController;

  SyncIssueStatus _filter = SyncIssueStatus.open;
  SyncIssuesListStatus _status = SyncIssuesListStatus.idle;
  List<SyncIssue> _items = const <SyncIssue>[];
  String? _errorMessage;
  String? _retryingId;
  bool _sessionExpired = false;

  SyncIssueStatus get filter => _filter;
  SyncIssuesListStatus get status => _status;
  List<SyncIssue> get items => List.unmodifiable(_items);
  String? get errorMessage => _errorMessage;
  String? get retryingId => _retryingId;
  bool get sessionExpired => _sessionExpired;

  Future<void> load({bool refresh = false}) async {
    if (_status == SyncIssuesListStatus.loading && !refresh) return;
    if (!refresh &&
        (_status == SyncIssuesListStatus.loaded ||
            _status == SyncIssuesListStatus.empty)) {
      return;
    }
    _errorMessage = null;
    _status = SyncIssuesListStatus.loading;
    notifyListeners();
    try {
      final result = await _repository.list(status: _filter);
      _items = result.items;
      _status = _items.isEmpty
          ? SyncIssuesListStatus.empty
          : SyncIssuesListStatus.loaded;
      notifyListeners();
    } on Object catch (error) {
      _errorMessage = _messageFor(error);
      _status = SyncIssuesListStatus.error;
      await _handleSessionExpiry(error);
      notifyListeners();
    }
  }

  Future<void> setFilter(SyncIssueStatus filter) async {
    if (_filter == filter) return;
    _filter = filter;
    await load(refresh: true);
  }

  Future<void> retry(String id) async {
    if (_retryingId != null) return;
    _retryingId = id;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.retry(id);
      await load(refresh: true);
    } on Object catch (error) {
      _errorMessage = _messageFor(error);
      await _handleSessionExpiry(error);
      notifyListeners();
    } finally {
      _retryingId = null;
      notifyListeners();
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'El servidor devolvió datos inválidos.';
    }
    return 'No se pudieron cargar las incidencias.';
  }

  Future<void> _handleSessionExpiry(Object error) async {
    if (error is! ApiException || !error.isUnauthorized) return;
    _sessionExpired = true;
    if (sessionController != null) await sessionController!.logout();
  }
}
