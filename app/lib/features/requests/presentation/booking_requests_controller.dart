import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../data/booking_requests_repository.dart';
import '../domain/booking_request.dart';
import '../domain/booking_request_status.dart';

enum BookingRequestsListStatus { idle, loading, ready, empty, error }

enum BookingRequestsFilter { pending, booked, expired, cancelled }

enum BookingRequestDetailStatus { idle, loading, ready, error }

enum BookingRequestMutationStatus { idle, submitting, success, error }

class BookingRequestsController extends ChangeNotifier {
  BookingRequestsController(this._repository, {this._sessionController});

  final BookingRequestsRepository _repository;
  final AdminSessionController? _sessionController;

  BookingRequestsListStatus _listStatus = BookingRequestsListStatus.idle;
  BookingRequestDetailStatus _detailStatus = BookingRequestDetailStatus.idle;
  BookingRequestMutationStatus _mutationStatus =
      BookingRequestMutationStatus.idle;
  final List<BookingRequest> _items = <BookingRequest>[];
  String? _nextCursor;
  BookingRequestDetail? _detail;
  String? _listError;
  String? _detailError;
  String? _mutationError;
  bool _sessionExpired = false;
  BookingRequestStatus? _statusFilter;
  BookingRequestsFilter _filter = BookingRequestsFilter.pending;

  BookingRequestsListStatus get listStatus => _listStatus;
  BookingRequestDetailStatus get detailStatus => _detailStatus;
  BookingRequestMutationStatus get mutationStatus => _mutationStatus;
  List<BookingRequest> get items => List.unmodifiable(_items);
  String? get nextCursor => _nextCursor;
  BookingRequestDetail? get detail => _detail;
  String? get listError => _listError;
  String? get detailError => _detailError;
  String? get mutationError => _mutationError;
  bool get sessionExpired => _sessionExpired;
  BookingRequestStatus? get statusFilter => _statusFilter;
  BookingRequestsFilter get filter => _filter;

  Future<void> load({
    bool refresh = false,
    BookingRequestStatus? status,
  }) async {
    if (status != null && status != _statusFilter) {
      _statusFilter = status;
      _filter = BookingRequestsFilter.values.firstWhere(
        (value) => value.apiStatus == status,
        orElse: () => BookingRequestsFilter.pending,
      );
      refresh = true;
    }
    if (_listStatus == BookingRequestsListStatus.loading) return;
    if (!refresh &&
        _items.isNotEmpty &&
        _listStatus == BookingRequestsListStatus.ready) {
      return;
    }

    if (refresh) {
      _items.clear();
      _nextCursor = null;
    }
    _listError = null;
    _listStatus = BookingRequestsListStatus.loading;
    notifyListeners();

    try {
      final page = await _repository.list(status: _statusFilter);
      _replacePage(page);
      _listStatus = _items.isEmpty
          ? BookingRequestsListStatus.empty
          : BookingRequestsListStatus.ready;
      notifyListeners();
    } on Object catch (error) {
      await _failList(error);
    }
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (cursor == null ||
        cursor.isEmpty ||
        _listStatus == BookingRequestsListStatus.loading) {
      return;
    }

    _listError = null;
    _listStatus = BookingRequestsListStatus.loading;
    notifyListeners();
    try {
      final page = await _repository.list(
        status: _statusFilter,
        cursor: cursor,
      );
      _appendPage(page);
      _listStatus = _items.isEmpty
          ? BookingRequestsListStatus.empty
          : BookingRequestsListStatus.ready;
      notifyListeners();
    } on Object catch (error) {
      await _failList(error);
    }
  }

  Future<void> clearStatusFilter() async {
    _statusFilter = null;
    _filter = BookingRequestsFilter.cancelled;
    await load(refresh: true);
  }

  Future<void> setFilter(BookingRequestsFilter filter) async {
    if (_filter == filter && _listStatus != BookingRequestsListStatus.idle) {
      return;
    }
    _filter = filter;
    _statusFilter = filter.apiStatus;
    await load(refresh: true);
  }

  Future<void> loadDetail(String id) async {
    _detailError = null;
    _detailStatus = BookingRequestDetailStatus.loading;
    notifyListeners();
    try {
      _detail = await _repository.detail(id);
      _detailStatus = BookingRequestDetailStatus.ready;
      notifyListeners();
    } on Object catch (error) {
      await _failDetail(error);
    }
  }

  Future<LinkReadyData?> create(CreateBookingRequestInput input) async {
    _beginMutation();
    try {
      final result = await _repository.create(input);
      _mutationStatus = BookingRequestMutationStatus.success;
      notifyListeners();
      return result.link;
    } on Object catch (error) {
      await _failMutation(error);
      return null;
    }
  }

  Future<LinkReadyData?> renew(String id, {int? ttlHours}) async {
    _beginMutation();
    try {
      final result = await _repository.renew(id, tokenTtlHours: ttlHours);
      _mutationStatus = BookingRequestMutationStatus.success;
      notifyListeners();
      return result.link;
    } on Object catch (error) {
      await _failMutation(error);
      return null;
    }
  }

  Future<void> revoke(String id) async {
    await _transition(id, _repository.revoke);
  }

  Future<void> close(String id) async {
    await _transition(id, _repository.close);
  }

  void clearError() {
    if (_listError == null &&
        _detailError == null &&
        _mutationError == null &&
        !_sessionExpired) {
      return;
    }
    _listError = null;
    _detailError = null;
    _mutationError = null;
    _sessionExpired = false;
    notifyListeners();
  }

  void _beginMutation() {
    _mutationError = null;
    _mutationStatus = BookingRequestMutationStatus.submitting;
    notifyListeners();
  }

  Future<void> _transition(
    String id,
    Future<BookingRequest> Function(String id) transition,
  ) async {
    _beginMutation();
    try {
      final request = await transition(id);
      _replaceRequest(request);
      _mutationStatus = BookingRequestMutationStatus.success;
      notifyListeners();
    } on Object catch (error) {
      await _failMutation(error);
    }
  }

  void _replacePage(BookingRequestPage page) {
    _items
      ..clear()
      ..addAll(page.items);
    _nextCursor = page.nextCursor;
  }

  void _appendPage(BookingRequestPage page) {
    final knownIds = _items.map((item) => item.id).toSet();
    for (final item in page.items) {
      if (knownIds.add(item.id)) _items.add(item);
    }
    _nextCursor = page.nextCursor;
  }

  void _replaceRequest(BookingRequest request) {
    final index = _items.indexWhere((item) => item.id == request.id);
    if (index >= 0) _items[index] = request;
    if (_detail?.request.id == request.id) {
      _detail = BookingRequestDetail(
        request: request,
        currentLink: _detail!.currentLink,
        audit: _detail!.audit,
      );
    }
  }

  Future<void> _failList(Object error) async {
    _listStatus = _items.isEmpty
        ? BookingRequestsListStatus.error
        : BookingRequestsListStatus.ready;
    _listError = _messageFor(error);
    await _handleSessionExpiry(error);
    notifyListeners();
  }

  Future<void> _failDetail(Object error) async {
    _detailStatus = BookingRequestDetailStatus.error;
    _detailError = _messageFor(error);
    await _handleSessionExpiry(error);
    notifyListeners();
  }

  Future<void> _failMutation(Object error) async {
    _mutationStatus = BookingRequestMutationStatus.error;
    _mutationError = _messageFor(error);
    await _handleSessionExpiry(error);
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'El servidor devolvió datos inválidos.';
    }
    return 'No se pudo completar la solicitud.';
  }

  Future<void> _handleSessionExpiry(Object error) async {
    if (error is! ApiException || !error.isUnauthorized) return;
    _sessionExpired = true;
    if (_sessionController != null) {
      await _sessionController.logout();
    }
  }
}

extension BookingRequestsFilterApi on BookingRequestsFilter {
  BookingRequestStatus? get apiStatus => switch (this) {
    BookingRequestsFilter.pending => BookingRequestStatus.pending,
    BookingRequestsFilter.booked => BookingRequestStatus.booked,
    BookingRequestsFilter.expired => BookingRequestStatus.expired,
    BookingRequestsFilter.cancelled => null,
  };
}
