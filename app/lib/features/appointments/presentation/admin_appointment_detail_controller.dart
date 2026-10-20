import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../agenda/domain/availability.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../data/admin_appointments_repository.dart';
import '../domain/admin_appointment.dart';

enum AdminAppointmentDetailStatus { idle, loading, loaded, error }

enum AdminAppointmentAction { reschedule, complete, noShow, cancel, retrySync }

class AdminAppointmentDetailController extends ChangeNotifier {
  AdminAppointmentDetailController(
    this._repository, {
    this.sessionController,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const rescheduleHorizonDays = 21;

  final AdminAppointmentsRepository _repository;
  final AdminSessionController? sessionController;
  final DateTime Function() _now;

  AdminAppointmentDetailStatus _status = AdminAppointmentDetailStatus.idle;
  AdminAppointmentDetail? _detail;
  AdminAvailability? _availability;
  String? _loadedId;
  String? _errorMessage;
  String? _actionError;
  AdminAppointmentAction? _busyAction;

  AdminAppointmentDetailStatus get status => _status;
  AdminAppointmentDetail? get detail => _detail;
  String? get errorMessage => _errorMessage;
  String? get actionError => _actionError;
  AdminAppointmentAction? get busyAction => _busyAction;
  bool get isBusy => _busyAction != null;
  bool get hasAvailability => _availability != null;

  Future<void> load(String id) async {
    if (_busyAction != null) return;
    if (_loadedId != id) _detail = null;
    _loadedId = id;
    _errorMessage = null;
    _actionError = null;
    _status = AdminAppointmentDetailStatus.loading;
    notifyListeners();
    try {
      _detail = await _repository.detail(id);
      _status = AdminAppointmentDetailStatus.loaded;
    } on Object catch (error) {
      _errorMessage = _messageFor(error, 'No se pudo cargar la cita.');
      _status = AdminAppointmentDetailStatus.error;
      await _handleSessionExpiry(error);
    }
    notifyListeners();
  }

  Future<void> loadAvailability() async {
    try {
      _availability = await _repository.availability();
      notifyListeners();
    } on Object catch (error) {
      await _handleSessionExpiry(error);
    }
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }

  /// Días con jornada abierta dentro del horizonte de reprogramación.
  List<DateTime> rescheduleDays({DateTime? now}) {
    final availability = _availability;
    if (availability == null) return const <DateTime>[];
    final today = _dateOnly(now ?? _now());
    return [
      for (var i = 0; i < rescheduleHorizonDays; i++)
        if (availability
            .windowsFor(today.add(Duration(days: i)).weekday % 7)
            .isNotEmpty)
          today.add(Duration(days: i)),
    ];
  }

  /// Inicios posibles para [day]; el servidor los revalida al guardar.
  List<DateTime> rescheduleTimes(DateTime day, {DateTime? now}) {
    final availability = _availability;
    final detail = _detail;
    if (availability == null || detail == null) return const <DateTime>[];
    final clock = now ?? _now();
    final date = _dateOnly(day);
    final step = availability.slotStepMinutes;
    final times = <DateTime>[];
    for (final window in availability.windowsFor(date.weekday % 7)) {
      for (
        var minute = window.startMinutes;
        minute + detail.durationMinutes <= window.endMinutes;
        minute += step
      ) {
        final start = date.add(Duration(minutes: minute));
        if (start.isAfter(clock)) times.add(start);
      }
    }
    return times;
  }

  Future<bool> reschedule(DateTime startAt) {
    final detail = _detail;
    if (detail == null) return Future.value(false);
    return _run(
      AdminAppointmentAction.reschedule,
      () => _repository.reschedule(
        detail.id,
        startAt: startAt,
        version: detail.version,
      ),
    );
  }

  Future<bool> complete() => _versioned(
    AdminAppointmentAction.complete,
    (id, version) => _repository.complete(id, version: version),
  );

  Future<bool> noShow() => _versioned(
    AdminAppointmentAction.noShow,
    (id, version) => _repository.noShow(id, version: version),
  );

  Future<bool> cancel() => _versioned(
    AdminAppointmentAction.cancel,
    (id, version) => _repository.cancel(id, version: version),
  );

  Future<bool> retrySync() {
    final detail = _detail;
    if (detail == null) return Future.value(false);
    return _run(AdminAppointmentAction.retrySync, () async {
      await _repository.retrySync(detail.id);
      return _repository.detail(detail.id);
    });
  }

  Future<bool> _versioned(
    AdminAppointmentAction action,
    Future<AdminAppointmentDetail> Function(String id, int version) call,
  ) {
    final detail = _detail;
    if (detail == null) return Future.value(false);
    return _run(action, () => call(detail.id, detail.version));
  }

  Future<bool> _run(
    AdminAppointmentAction action,
    Future<AdminAppointmentDetail> Function() call,
  ) async {
    if (_busyAction != null) return false;
    _busyAction = action;
    _actionError = null;
    notifyListeners();
    try {
      _detail = await call();
      return true;
    } on Object catch (error) {
      _actionError = _messageFor(error, 'No se pudo completar la acción.');
      await _handleSessionExpiry(error);
      return false;
    } finally {
      _busyAction = null;
      notifyListeners();
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _messageFor(Object error, String fallback) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'El servidor devolvió datos inválidos.';
    }
    return fallback;
  }

  Future<void> _handleSessionExpiry(Object error) async {
    if (error is! ApiException || !error.isUnauthorized) return;
    await sessionController?.logout();
  }
}
