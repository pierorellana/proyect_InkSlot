import 'dart:js_interop';

@JS('inkSlotFormatTime')
external JSString _formatTime(JSNumber timestamp, JSString timezone);

String formatPublicTime(DateTime utc, String timezone) =>
    _formatTime(utc.toUtc().millisecondsSinceEpoch.toJS, timezone.toJS).toDart;
