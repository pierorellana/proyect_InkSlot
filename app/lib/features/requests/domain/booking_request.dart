import 'booking_request_status.dart';

class BookingRequestClient {
  const BookingRequestClient({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.contactChannel,
    this.contactValue,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final ContactChannel? contactChannel;
  final String? contactValue;

  factory BookingRequestClient.fromJson(Map<String, dynamic> json) {
    return BookingRequestClient(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      email: _nullableString(json, 'email'),
      phone: _nullableString(json, 'phone'),
      contactChannel: _nullableEnum(
        json,
        'contactChannel',
        ContactChannel.fromApi,
      ),
      contactValue: _nullableString(json, 'contactValue'),
    );
  }
}

class BookingRestrictionWindow {
  const BookingRestrictionWindow({
    required this.startLocal,
    required this.endLocal,
  });

  final String startLocal;
  final String endLocal;

  factory BookingRestrictionWindow.fromJson(Map<String, dynamic> json) {
    return BookingRestrictionWindow(
      startLocal: _requiredString(json, 'startLocal'),
      endLocal: _requiredString(json, 'endLocal'),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'startLocal': startLocal,
    'endLocal': endLocal,
  };
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.client,
    required this.paymentReference,
    required this.depositVerified,
    required this.durationMinutes,
    required this.status,
    required this.minDate,
    required this.maxDate,
    required this.allowedWeekdays,
    required this.allowedWindows,
    required this.createdAt,
  });

  final String id;
  final BookingRequestClient client;
  final String? paymentReference;
  final bool depositVerified;
  final int durationMinutes;
  final BookingRequestStatus status;
  final DateTime? minDate;
  final DateTime? maxDate;
  final List<int>? allowedWeekdays;
  final List<BookingRestrictionWindow>? allowedWindows;
  final DateTime createdAt;

  factory BookingRequest.fromJson(Map<String, dynamic> json) {
    return BookingRequest(
      id: _requiredString(json, 'id'),
      client: _requiredMap(json, 'client').let(BookingRequestClient.fromJson),
      paymentReference: _nullableString(json, 'paymentReference'),
      depositVerified: _requiredBool(json, 'depositVerified'),
      durationMinutes: _requiredInt(json, 'durationMinutes'),
      status: BookingRequestStatus.fromApi(json['status']),
      minDate: _nullableDate(json, 'minDate'),
      maxDate: _nullableDate(json, 'maxDate'),
      allowedWeekdays: _nullableIntList(json, 'allowedWeekdays'),
      allowedWindows: _nullableWindowList(json, 'allowedWindows'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }
}

class BookingRequestPage {
  const BookingRequestPage({required this.items, required this.nextCursor});

  final List<BookingRequest> items;
  final String? nextCursor;

  factory BookingRequestPage.fromJson(Map<String, dynamic> json) {
    final items = _requiredList(json, 'items');
    return BookingRequestPage(
      items: items
          .map((item) {
            return BookingRequest.fromJson(_asMap(item, 'items[]'));
          })
          .toList(growable: false),
      nextCursor: _nullableString(json, 'nextCursor'),
    );
  }
}

class BookingRequestAuditEntry {
  const BookingRequestAuditEntry({
    required this.action,
    required this.createdAt,
  });

  final String action;
  final DateTime createdAt;

  factory BookingRequestAuditEntry.fromJson(Map<String, dynamic> json) {
    return BookingRequestAuditEntry(
      action: _requiredString(json, 'action'),
      createdAt: _requiredDate(json, 'createdAt'),
    );
  }
}

class CurrentBookingLink {
  const CurrentBookingLink({required this.status, required this.expiresAt});

  final BookingLinkStatus status;
  final DateTime expiresAt;

  factory CurrentBookingLink.fromJson(Map<String, dynamic> json) {
    return CurrentBookingLink(
      status: BookingLinkStatus.fromApi(json['status']),
      expiresAt: _requiredDate(json, 'expiresAt'),
    );
  }
}

class BookingRequestDetail {
  const BookingRequestDetail({
    required this.request,
    required this.currentLink,
    required this.audit,
  });

  final BookingRequest request;
  final CurrentBookingLink? currentLink;
  final List<BookingRequestAuditEntry> audit;

  factory BookingRequestDetail.fromJson(Map<String, dynamic> json) {
    final audit = _requiredList(json, 'audit');
    return BookingRequestDetail(
      request: BookingRequest.fromJson(_requiredMap(json, 'request')),
      currentLink: _nullableMap(
        json,
        'currentLink',
      )?.let(CurrentBookingLink.fromJson),
      audit: audit
          .map((entry) {
            return BookingRequestAuditEntry.fromJson(_asMap(entry, 'audit[]'));
          })
          .toList(growable: false),
    );
  }
}

class LinkReadyData {
  const LinkReadyData({required this.path, required this.expiresAt});

  final String path;
  final DateTime expiresAt;

  factory LinkReadyData.fromJson(Map<String, dynamic> json) {
    final path = _requiredString(json, 'path');
    if (path.isEmpty) {
      throw const FormatException('El enlace recibido está vacío.');
    }
    return LinkReadyData(
      path: path,
      expiresAt: _requiredDate(json, 'expiresAt'),
    );
  }
}

class BookingRequestActionResult {
  const BookingRequestActionResult({required this.request, required this.link});

  final BookingRequest request;
  final LinkReadyData link;
}

class CreateBookingRequestInput {
  const CreateBookingRequestInput({
    required this.clientName,
    this.contactChannel,
    this.contactValue,
    this.paymentReference,
    required this.depositVerified,
    required this.durationMinutes,
    this.restrictionNotes,
    this.preferredDate,
    this.preferredTimeRange,
    this.preferredDays = const <String>[],
    this.tokenTtlHours,
  });

  final String clientName;
  final ContactChannel? contactChannel;
  final String? contactValue;
  final String? paymentReference;
  final bool depositVerified;
  final int durationMinutes;
  // The current API has no notes field; this remains available to the form
  // model without being sent as an unsupported request property.
  final String? restrictionNotes;
  final DateTime? preferredDate;
  final String? preferredTimeRange;
  final List<String> preferredDays;
  final int? tokenTtlHours;
}

extension<T> on T {
  R let<R>(R Function(T value) transform) => transform(this);
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El campo "$key" no tiene un objeto válido.');
}

Map<String, dynamic>? _nullableMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El campo "$key" no tiene un objeto válido.');
}

List<dynamic> _requiredList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is List) return value;
  throw FormatException('El campo "$key" no tiene una lista válida.');
}

Map<String, dynamic> _asMap(Object? value, String field) {
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('El elemento "$field" no tiene un objeto válido.');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('El campo "$key" no tiene un texto válido.');
}

String? _nullableString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('El campo "$key" no tiene un texto válido.');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('El campo "$key" no tiene un booleano válido.');
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('El campo "$key" no tiene un entero válido.');
}

DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = _parseUtcDate(value);
  if (parsed == null) {
    throw FormatException('El campo "$key" no tiene una fecha válida.');
  }
  return parsed.toUtc();
}

DateTime? _nullableDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException('El campo "$key" no tiene una fecha válida.');
  }
  final parsed = _parseUtcDate(value);
  if (parsed == null) {
    throw FormatException('El campo "$key" no tiene una fecha válida.');
  }
  return parsed.toUtc();
}

DateTime? _parseUtcDate(String value) {
  final dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (dateOnly != null) {
    return DateTime.utc(
      int.parse(dateOnly.group(1)!),
      int.parse(dateOnly.group(2)!),
      int.parse(dateOnly.group(3)!),
    );
  }
  return DateTime.tryParse(value)?.toUtc();
}

List<int>? _nullableIntList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! List) {
    throw FormatException('El campo "$key" no tiene una lista válida.');
  }
  return value
      .map((item) {
        if (item is int) return item;
        throw FormatException('El campo "$key" contiene un entero inválido.');
      })
      .toList(growable: false);
}

List<BookingRestrictionWindow>? _nullableWindowList(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];
  if (value == null) return null;
  if (value is! List) {
    throw FormatException('El campo "$key" no tiene una lista válida.');
  }
  return value
      .map((item) {
        return BookingRestrictionWindow.fromJson(_asMap(item, '$key[]'));
      })
      .toList(growable: false);
}

T? _nullableEnum<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Object? value) parser,
) {
  if (!json.containsKey(key) || json[key] == null) return null;
  return parser(json[key]);
}
