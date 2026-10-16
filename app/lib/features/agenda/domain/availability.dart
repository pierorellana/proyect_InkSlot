class WeeklyWindow {
  const WeeklyWindow({
    required this.weekday,
    required this.startLocal,
    required this.endLocal,
  });

  /// 0 = domingo … 6 = sábado, como en el API.
  final int weekday;
  final String startLocal;
  final String endLocal;

  factory WeeklyWindow.fromJson(Map<String, dynamic> json) {
    final weekday = json['weekday'];
    final start = json['startLocal'];
    final end = json['endLocal'];
    if (weekday is! int ||
        weekday < 0 ||
        weekday > 6 ||
        start is! String ||
        end is! String) {
      throw const FormatException('Una ventana semanal no es válida.');
    }
    return WeeklyWindow(weekday: weekday, startLocal: start, endLocal: end);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'weekday': weekday,
    'startLocal': startLocal,
    'endLocal': endLocal,
  };

  int get startMinutes => _minutes(startLocal);
  int get endMinutes => _minutes(endLocal);

  static int _minutes(String value) {
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class AdminAvailability {
  const AdminAvailability({
    required this.timezone,
    required this.slotStepMinutes,
    required this.bufferMinutes,
    required this.minimumNoticeHours,
    required this.horizonDays,
    required this.weeklyWindows,
  });

  static const defaults = AdminAvailability(
    timezone: 'America/Guayaquil',
    slotStepMinutes: 30,
    bufferMinutes: 15,
    minimumNoticeHours: 24,
    horizonDays: 60,
    weeklyWindows: <WeeklyWindow>[],
  );

  final String timezone;
  final int slotStepMinutes;
  final int bufferMinutes;
  final int minimumNoticeHours;
  final int horizonDays;
  final List<WeeklyWindow> weeklyWindows;

  factory AdminAvailability.fromJson(Map<String, dynamic> json) {
    final windows = json['weeklyWindows'];
    final timezone = json['timezone'];
    if (windows is! List || timezone is! String) {
      throw const FormatException('La disponibilidad no es válida.');
    }
    int number(String key) {
      final value = json[key];
      if (value is int) return value;
      throw FormatException('El campo "$key" no tiene un entero válido.');
    }

    return AdminAvailability(
      timezone: timezone,
      slotStepMinutes: number('slotStepMinutes'),
      bufferMinutes: number('bufferMinutes'),
      minimumNoticeHours: number('minimumNoticeHours'),
      horizonDays: number('horizonDays'),
      weeklyWindows: windows
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Una ventana semanal no es válida.');
            }
            return WeeklyWindow.fromJson(Map<String, dynamic>.from(item));
          })
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'timezone': timezone,
    'slotStepMinutes': slotStepMinutes,
    'bufferMinutes': bufferMinutes,
    'minimumNoticeHours': minimumNoticeHours,
    'horizonDays': horizonDays,
    'weeklyWindows': weeklyWindows.map((w) => w.toJson()).toList(),
  };

  AdminAvailability copyWith({List<WeeklyWindow>? weeklyWindows}) =>
      AdminAvailability(
        timezone: timezone,
        slotStepMinutes: slotStepMinutes,
        bufferMinutes: bufferMinutes,
        minimumNoticeHours: minimumNoticeHours,
        horizonDays: horizonDays,
        weeklyWindows: weeklyWindows ?? this.weeklyWindows,
      );

  List<WeeklyWindow> windowsFor(int weekday) =>
      weeklyWindows.where((w) => w.weekday == weekday).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
}

class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.startAt,
    required this.endAt,
    this.reason,
  });

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final String? reason;

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final start = json['startAt'];
    final end = json['endAt'];
    final reason = json['reason'];
    if (id is! String ||
        start is! String ||
        end is! String ||
        (reason != null && reason is! String)) {
      throw const FormatException('Un bloqueo no es válido.');
    }
    final startAt = DateTime.tryParse(start);
    final endAt = DateTime.tryParse(end);
    if (startAt == null || endAt == null) {
      throw const FormatException('Las fechas de un bloqueo no son válidas.');
    }
    return AvailabilityBlock(
      id: id,
      startAt: startAt,
      endAt: endAt,
      reason: reason as String?,
    );
  }
}
