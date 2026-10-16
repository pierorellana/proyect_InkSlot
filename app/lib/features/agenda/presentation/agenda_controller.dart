import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/presentation/admin_session_controller.dart';
import '../data/agenda_repository.dart';
import '../domain/availability.dart';
import '../domain/calendar_status.dart';

enum AgendaLoadStatus { idle, loading, loaded, error }

class AgendaController extends ChangeNotifier {
  AgendaController(this._repository, {this.sessionController});

  static const defaultStart = '10:00';
  static const defaultEnd = '20:00';

  final AgendaRepository _repository;
  final AdminSessionController? sessionController;

  AgendaLoadStatus _status = AgendaLoadStatus.idle;
  CalendarStatus? _calendar;
  AdminAvailability? _availability;
  List<AvailabilityBlock> _blocks = const <AvailabilityBlock>[];
  final Map<int, List<WeeklyWindow>> _closedMemory =
      <int, List<WeeklyWindow>>{};
  String? _errorMessage;
  String? _actionError;
  bool _connecting = false;
  bool _savingWeek = false;
  bool _mutatingBlock = false;
  bool _loading = false;

  AgendaLoadStatus get status => _status;
  CalendarStatus? get calendar => _calendar;
  AdminAvailability? get availability => _availability;
  AdminAvailability get effectiveAvailability =>
      _availability ?? AdminAvailability.defaults;
  List<AvailabilityBlock> get blocks => List.unmodifiable(_blocks);
  String? get errorMessage => _errorMessage;
  String? get actionError => _actionError;
  bool get connecting => _connecting;
  bool get savingWeek => _savingWeek;
  bool get mutatingBlock => _mutatingBlock;

  Future<void> load({bool refresh = false}) async {
    if (_loading) return;
    if (!refresh && _status == AgendaLoadStatus.loaded) return;
    _loading = true;
    _errorMessage = null;
    if (_status != AgendaLoadStatus.loaded) {
      _status = AgendaLoadStatus.loading;
    }
    notifyListeners();
    try {
      final results = await Future.wait<Object?>([
        _repository.calendarStatus(),
        _repository.availability(),
        _repository.blocks(),
      ]);
      _calendar = results[0]! as CalendarStatus;
      _availability = results[1] as AdminAvailability?;
      _blocks = results[2]! as List<AvailabilityBlock>;
      _status = AgendaLoadStatus.loaded;
    } on Object catch (error) {
      _errorMessage = _messageFor(error, 'No se pudo cargar tu agenda.');
      if (_status != AgendaLoadStatus.loaded) _status = AgendaLoadStatus.error;
      await _handleSessionExpiry(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }

  /// Pide la URL OAuth (conectar o reconectar) para abrirla en el navegador.
  Future<CalendarAuthorization?> requestAuthorization() async {
    if (_connecting) return null;
    final reconnect =
        _calendar?.state == CalendarConnectionState.needsReconnect ||
        _calendar?.state == CalendarConnectionState.error;
    _connecting = true;
    _actionError = null;
    notifyListeners();
    try {
      return reconnect
          ? await _repository.reconnectCalendar()
          : await _repository.connectCalendar();
    } on Object catch (error) {
      _actionError = _messageFor(
        error,
        'No se pudo iniciar la conexión con Google.',
      );
      await _handleSessionExpiry(error);
      return null;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<bool> disconnect() async {
    if (_connecting) return false;
    _connecting = true;
    _actionError = null;
    notifyListeners();
    try {
      await _repository.disconnectCalendar();
      _calendar = await _repository.calendarStatus();
      return true;
    } on Object catch (error) {
      _actionError = _messageFor(
        error,
        'No se pudo desconectar el calendario.',
      );
      await _handleSessionExpiry(error);
      return false;
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  Future<void> refreshCalendar() async {
    try {
      _calendar = await _repository.calendarStatus();
      notifyListeners();
    } on Object catch (error) {
      await _handleSessionExpiry(error);
    }
  }

  Future<bool> setDayOpen(int weekday, bool open) async {
    if (_savingWeek) return false;
    final current = effectiveAvailability;
    final dayWindows = current.windowsFor(weekday);
    if (open == dayWindows.isNotEmpty) return true;

    final others = current.weeklyWindows
        .where((w) => w.weekday != weekday)
        .toList();
    final List<WeeklyWindow> next;
    if (open) {
      next = [
        ...others,
        ..._closedMemory.remove(weekday) ??
            [
              WeeklyWindow(
                weekday: weekday,
                startLocal: defaultStart,
                endLocal: defaultEnd,
              ),
            ],
      ];
    } else {
      _closedMemory[weekday] = dayWindows;
      next = others;
    }

    _savingWeek = true;
    _actionError = null;
    notifyListeners();
    try {
      _availability = await _repository.updateAvailability(
        current.copyWith(weeklyWindows: next),
      );
      return true;
    } on Object catch (error) {
      _closedMemory.remove(weekday);
      if (!open) _closedMemory[weekday] = dayWindows;
      _actionError = _messageFor(error, 'No se pudo guardar tu jornada.');
      await _handleSessionExpiry(error);
      return false;
    } finally {
      _savingWeek = false;
      notifyListeners();
    }
  }

  Future<bool> addBlock({
    required DateTime startAt,
    required DateTime endAt,
    String? reason,
  }) async {
    if (_mutatingBlock) return false;
    _mutatingBlock = true;
    _actionError = null;
    notifyListeners();
    try {
      final block = await _repository.createBlock(
        startAt: startAt,
        endAt: endAt,
        reason: reason,
      );
      _blocks = [..._blocks, block]
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return true;
    } on Object catch (error) {
      _actionError = _messageFor(error, 'No se pudo crear el bloqueo.');
      await _handleSessionExpiry(error);
      return false;
    } finally {
      _mutatingBlock = false;
      notifyListeners();
    }
  }

  Future<bool> removeBlock(String id) async {
    if (_mutatingBlock) return false;
    _mutatingBlock = true;
    _actionError = null;
    notifyListeners();
    try {
      await _repository.deleteBlock(id);
      _blocks = _blocks.where((b) => b.id != id).toList(growable: false);
      return true;
    } on Object catch (error) {
      _actionError = _messageFor(error, 'No se pudo eliminar el bloqueo.');
      await _handleSessionExpiry(error);
      return false;
    } finally {
      _mutatingBlock = false;
      notifyListeners();
    }
  }

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
