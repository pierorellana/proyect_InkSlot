String formatPublicTime(DateTime utc, String timezone) {
  final local = utc.toUtc().add(
    Duration(minutes: _timezoneOffsetMinutes(timezone)),
  );
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

int _timezoneOffsetMinutes(String timezone) => switch (timezone) {
  'UTC' || 'GMT' => 0,
  'America/Guayaquil' || 'America/Lima' || 'America/Bogota' => -300,
  'America/Los_Angeles' => -480,
  'America/Denver' => -420,
  'America/Chicago' => -360,
  'America/New_York' => -300,
  'Europe/London' => 0,
  'Europe/Madrid' => 60,
  _ => 0,
};
