import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../data/public_reservation_repository.dart';
import '../domain/public_availability.dart';
import '../domain/public_appointment.dart';
import '../domain/public_confirmation.dart';
import '../domain/public_reservation.dart';

enum PublicReservationStatus {
  idle,
  loading,
  active,
  booked,
  expired,
  revoked,
  error,
}

enum PublicAvailabilityStatus {
  idle,
  loading,
  ready,
  empty,
  calendarUnavailable,
  offline,
  error,
}

enum PublicConfirmationStatus {
  idle,
  loading,
  confirmed,
  conflict,
  alreadyBooked,
  expired,
  revoked,
  calendarUnavailable,
  offline,
  error,
}

class PublicReservationController extends ChangeNotifier {
  PublicReservationController(this._repository);

  final PublicReservationRepository _repository;

  PublicReservationStatus _reservationStatus = PublicReservationStatus.idle;
  PublicAvailabilityStatus _availabilityStatus = PublicAvailabilityStatus.idle;
  PublicReservation? _reservation;
  PublicAvailability? _availability;
  AvailabilityDay? _selectedDay;
  AvailabilitySlot? _selectedSlot;
  PublicConfirmationStatus _confirmationStatus = PublicConfirmationStatus.idle;
  PublicConfirmation? _confirmation;
  PublicAppointment? _appointment;
  String? _token;
  String? _reservationError;
  String? _availabilityError;
  String? _confirmationError;
  DateTime? _lastFrom;
  DateTime? _lastTo;
  String? _idempotencyKey;
  AvailabilitySlot? _idempotencySlot;
  int _idempotencySequence = 0;

  PublicReservationStatus get reservationStatus => _reservationStatus;
  PublicAvailabilityStatus get availabilityStatus => _availabilityStatus;
  PublicReservation? get reservation => _reservation;
  PublicAvailability? get availability => _availability;
  AvailabilityDay? get selectedDay => _selectedDay;
  AvailabilitySlot? get selectedSlot => _selectedSlot;
  PublicConfirmationStatus get confirmationStatus => _confirmationStatus;
  PublicConfirmation? get confirmation => _confirmation;
  PublicAppointment? get appointment => _appointment;
  String? get reservationError => _reservationError;
  String? get availabilityError => _availabilityError;
  String? get confirmationError => _confirmationError;
  String? get token => _token;
  DateTime? get lastFrom => _lastFrom;
  DateTime? get lastTo => _lastTo;

  Future<void> loadReservation(String token) async {
    if (_token == token &&
        (_reservationStatus == PublicReservationStatus.loading ||
            _reservationStatus == PublicReservationStatus.active ||
            _reservationStatus == PublicReservationStatus.booked)) {
      return;
    }

    _token = token;
    _reservation = null;
    _availability = null;
    _selectedDay = null;
    _selectedSlot = null;
    _resetConfirmationState();
    _resetConfirmationState();
    _reservationError = null;
    _availabilityError = null;
    _availabilityStatus = PublicAvailabilityStatus.idle;
    _reservationStatus = PublicReservationStatus.loading;
    notifyListeners();

    try {
      final reservation = await _repository.getReservation(token);
      if (_token != token) return;
      _reservation = reservation;
      _reservationStatus = reservation.isBooked
          ? PublicReservationStatus.booked
          : PublicReservationStatus.active;
      notifyListeners();
    } on Object catch (error) {
      if (_token != token) return;
      _reservationStatus = _reservationStatusFor(error);
      _reservationError = _messageFor(error);
      notifyListeners();
    }
  }

  Future<void> loadAvailability(
    String token,
    DateTime from,
    DateTime to,
  ) async {
    _token = token;
    _lastFrom = _dateOnlyValue(from);
    _lastTo = _dateOnlyValue(to);
    _availability = null;
    _selectedDay = null;
    _selectedSlot = null;
    _availabilityError = null;
    _availabilityStatus = PublicAvailabilityStatus.loading;
    notifyListeners();

    try {
      final availability = await _repository.getAvailability(
        token,
        from: _lastFrom!,
        to: _lastTo!,
      );
      if (_token != token) return;
      _availability = availability;
      _availabilityStatus = availability.days.isEmpty
          ? PublicAvailabilityStatus.empty
          : PublicAvailabilityStatus.ready;
      notifyListeners();
    } on Object catch (error) {
      if (_token != token) return;
      _availabilityStatus = _availabilityStatusFor(error);
      _availabilityError = _messageFor(error);
      notifyListeners();
    }
  }

  void selectDate(DateTime? date) {
    if (date == null || _availability == null) {
      _selectedDay = null;
      _setSelectedSlot(null);
      notifyListeners();
      return;
    }
    final day = _availability!.days.cast<AvailabilityDay?>().firstWhere(
      (candidate) => candidate != null && _sameDate(candidate.date, date),
      orElse: () => null,
    );
    if (day == null || day.slots.isEmpty) return;
    _selectedDay = day;
    if (_selectedSlot != null && !_containsSlot(day.slots, _selectedSlot!)) {
      _setSelectedSlot(null);
    }
    notifyListeners();
  }

  void selectSlot(AvailabilitySlot? slot) {
    if (slot == null || _availability == null) {
      _setSelectedSlot(null);
      notifyListeners();
      return;
    }
    for (final day in _availability!.days) {
      if (_containsSlot(day.slots, slot)) {
        _selectedDay = day;
        _setSelectedSlot(slot);
        notifyListeners();
        return;
      }
    }
  }

  Future<PublicConfirmation?> confirmSelected(String token) async {
    final slot = _selectedSlot;
    if (slot == null ||
        _confirmationStatus == PublicConfirmationStatus.loading) {
      return null;
    }
    _token = token;
    final idempotencyKey = _keyFor(slot);
    _confirmationError = null;
    _confirmationStatus = PublicConfirmationStatus.loading;
    notifyListeners();

    try {
      final confirmation = await _repository.confirmReservation(
        token,
        slot.startAt,
        idempotencyKey: idempotencyKey,
      );
      if (_token != token) return null;
      _confirmation = confirmation;
      _appointment = null;
      _confirmationStatus = PublicConfirmationStatus.confirmed;
      _setSelectedSlot(null, resetConfirmation: false);
      _idempotencyKey = null;
      _idempotencySlot = null;
      notifyListeners();
      return confirmation;
    } on Object catch (error) {
      if (_token != token) return null;
      _confirmationStatus = _confirmationStatusFor(error);
      _confirmationError = _messageFor(error);
      notifyListeners();
      return null;
    }
  }

  Future<PublicAppointment?> loadAppointment(String token) async {
    _token = token;
    _appointment = null;
    _confirmation = null;
    _confirmationError = null;
    _confirmationStatus = PublicConfirmationStatus.loading;
    notifyListeners();

    try {
      final appointment = await _repository.getAppointment(token);
      if (_token != token) return null;
      _appointment = appointment;
      _confirmationStatus = PublicConfirmationStatus.confirmed;
      notifyListeners();
      return appointment;
    } on Object catch (error) {
      if (_token != token) return null;
      _confirmationStatus = _confirmationStatusFor(error);
      _confirmationError = _messageFor(error);
      notifyListeners();
      return null;
    }
  }

  Future<void> retryConfirmation() async {
    final token = _token;
    if (token == null) return;
    await confirmSelected(token);
  }

  Future<void> retryAppointment() async {
    final token = _token;
    if (token == null) return;
    await loadAppointment(token);
  }

  Future<void> retryReservation() async {
    final token = _token;
    if (token == null) return;
    await loadReservation(token);
  }

  Future<void> retryAvailability() async {
    final token = _token;
    final from = _lastFrom;
    final to = _lastTo;
    if (token == null || from == null || to == null) return;
    await loadAvailability(token, from, to);
  }

  PublicReservationStatus _reservationStatusFor(Object error) {
    if (error is! ApiException) return PublicReservationStatus.error;
    return switch (error.code) {
      'TOKEN_EXPIRED' => PublicReservationStatus.expired,
      'TOKEN_REVOKED' => PublicReservationStatus.revoked,
      'ALREADY_BOOKED' => PublicReservationStatus.booked,
      _ => PublicReservationStatus.error,
    };
  }

  PublicAvailabilityStatus _availabilityStatusFor(Object error) {
    if (error is ApiException && error.code == 'CALENDAR_UNAVAILABLE') {
      return PublicAvailabilityStatus.calendarUnavailable;
    }
    if (error is ApiException &&
        (error.code == 'NETWORK_ERROR' || error.code == 'OFFLINE')) {
      return PublicAvailabilityStatus.offline;
    }
    return PublicAvailabilityStatus.error;
  }

  PublicConfirmationStatus _confirmationStatusFor(Object error) {
    if (error is! ApiException) return PublicConfirmationStatus.error;
    return switch (error.code) {
      'SLOT_UNAVAILABLE' ||
      'IDEMPOTENCY_REUSED' => PublicConfirmationStatus.conflict,
      'ALREADY_BOOKED' => PublicConfirmationStatus.alreadyBooked,
      'TOKEN_EXPIRED' => PublicConfirmationStatus.expired,
      'TOKEN_REVOKED' => PublicConfirmationStatus.revoked,
      'CALENDAR_UNAVAILABLE' => PublicConfirmationStatus.calendarUnavailable,
      'NETWORK_ERROR' || 'OFFLINE' => PublicConfirmationStatus.offline,
      _ => PublicConfirmationStatus.error,
    };
  }

  String _messageFor(Object error) {
    if (error is ApiException) return error.message;
    if (error is FormatException) {
      return 'El servidor devolvió datos inválidos.';
    }
    return 'No se pudo completar la solicitud.';
  }

  bool _containsSlot(List<AvailabilitySlot> slots, AvailabilitySlot target) =>
      slots.any(
        (slot) => slot.startAt == target.startAt && slot.endAt == target.endAt,
      );

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  DateTime _dateOnlyValue(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _keyFor(AvailabilitySlot slot) {
    if (_idempotencyKey != null &&
        _idempotencySlot != null &&
        _sameSlot(_idempotencySlot!, slot)) {
      return _idempotencyKey!;
    }
    _idempotencySequence += 1;
    _idempotencyKey =
        'inkslot-${DateTime.now().microsecondsSinceEpoch}-$_idempotencySequence';
    _idempotencySlot = slot;
    return _idempotencyKey!;
  }

  void _setSelectedSlot(
    AvailabilitySlot? slot, {
    bool resetConfirmation = true,
  }) {
    if (_sameNullableSlot(_selectedSlot, slot)) return;
    _selectedSlot = slot;
    if (resetConfirmation) _resetConfirmationState();
  }

  void _resetConfirmationState() {
    _confirmationStatus = PublicConfirmationStatus.idle;
    _confirmation = null;
    _appointment = null;
    _confirmationError = null;
    _idempotencyKey = null;
    _idempotencySlot = null;
  }

  bool _sameNullableSlot(AvailabilitySlot? left, AvailabilitySlot? right) {
    if (left == null || right == null) return left == right;
    return _sameSlot(left, right);
  }

  bool _sameSlot(AvailabilitySlot left, AvailabilitySlot right) =>
      left.startAt == right.startAt && left.endAt == right.endAt;
}
