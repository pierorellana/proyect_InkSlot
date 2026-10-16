enum BookingRequestStatus {
  pending,
  booked,
  cancelled,
  expired,
  closed;

  static BookingRequestStatus fromApi(Object? value) {
    if (value is! String) {
      throw FormatException('El estado de la solicitud no es válido.');
    }

    return switch (value) {
      'pending' => BookingRequestStatus.pending,
      'booked' => BookingRequestStatus.booked,
      'cancelled' => BookingRequestStatus.cancelled,
      'expired' => BookingRequestStatus.expired,
      'closed' => BookingRequestStatus.closed,
      _ => throw FormatException(
        'El API devolvió un estado de solicitud desconocido: $value.',
      ),
    };
  }

  String get apiValue => name;
}

enum ContactChannel {
  whatsapp,
  instagram,
  email,
  phone;

  static ContactChannel fromApi(Object? value) {
    if (value is! String) {
      throw FormatException('El canal de contacto no es válido.');
    }

    return switch (value) {
      'whatsapp' => ContactChannel.whatsapp,
      'instagram' => ContactChannel.instagram,
      'email' => ContactChannel.email,
      'phone' => ContactChannel.phone,
      _ => throw FormatException(
        'El API devolvió un canal de contacto desconocido: $value.',
      ),
    };
  }

  String get apiValue => name;
}

enum BookingLinkStatus {
  active,
  expired,
  revoked,
  consumed;

  static BookingLinkStatus fromApi(Object? value) {
    if (value is! String) {
      throw FormatException('El estado del enlace no es válido.');
    }

    return switch (value) {
      'active' => BookingLinkStatus.active,
      'expired' => BookingLinkStatus.expired,
      'revoked' => BookingLinkStatus.revoked,
      'consumed' => BookingLinkStatus.consumed,
      _ => throw FormatException(
        'El API devolvió un estado de enlace desconocido: $value.',
      ),
    };
  }
}
