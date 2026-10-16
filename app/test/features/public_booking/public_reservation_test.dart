import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/domain/public_reservation.dart';

void main() {
  test('parses the private public summary without client data', () {
    final reservation = PublicReservation.fromJson(<String, dynamic>{
      'status': 'pending',
      'artist': <String, dynamic>{'displayName': 'Gio Ink'},
      'durationMinutes': 180,
      'timezone': 'America/Guayaquil',
      'restrictions': <String, dynamic>{
        'minDate': '2026-10-20',
        'maxDate': '2026-11-30',
        'allowedWeekdays': <int>[2, 3, 4, 5, 6],
        'allowedWindows': <Map<String, String>>[
          <String, String>{'startLocal': '10:00', 'endLocal': '20:00'},
        ],
      },
      'expiresAt': '2026-10-17T12:00:00.000Z',
    });

    expect(reservation.isPending, isTrue);
    expect(reservation.artistDisplayName, 'Gio Ink');
    expect(reservation.durationMinutes, 180);
    expect(reservation.restrictions.minDate, DateTime(2026, 10, 20));
    expect(reservation.restrictions.allowedWindows!.single.startLocal, '10:00');
  });

  test('rejects malformed public summary and slots', () {
    expect(
      () => PublicReservation.fromJson(<String, dynamic>{
        'status': 'pending',
        'artist': <String, dynamic>{'displayName': 'Gio Ink'},
        'durationMinutes': 180,
        'timezone': 'not a timezone',
        'restrictions': <String, dynamic>{},
        'expiresAt': '2026-10-17T12:00:00.000Z',
      }),
      throwsFormatException,
    );
    expect(
      () => AvailabilitySlot.fromJson(<String, dynamic>{
        'startAt': '2026-10-23T15:00:00.000Z',
        'endAt': '2026-10-23T15:00:00.000Z',
      }),
      throwsFormatException,
    );
  });

  test('keeps date-only days separate from UTC slot instants', () {
    final availability = PublicAvailability.fromJson(<String, dynamic>{
      'timezone': 'America/Guayaquil',
      'days': <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-10-23',
          'slots': <Map<String, String>>[
            <String, String>{
              'startAt': '2026-10-23T15:00:00.000Z',
              'endAt': '2026-10-23T18:00:00.000Z',
            },
          ],
        },
      ],
    });

    expect(availability.days.single.date, DateTime(2026, 10, 23));
    expect(availability.days.single.date.isUtc, isFalse);
    expect(availability.days.single.slots.single.startAt.isUtc, isTrue);
  });

  test('accepts overlapping start-time alternatives for a longer session', () {
    final availability = PublicAvailability.fromJson(<String, dynamic>{
      'timezone': 'America/Guayaquil',
      'days': <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-10-23',
          'slots': <Map<String, String>>[
            <String, String>{
              'startAt': '2026-10-23T15:00:00.000Z',
              'endAt': '2026-10-23T16:00:00.000Z',
            },
            <String, String>{
              'startAt': '2026-10-23T15:30:00.000Z',
              'endAt': '2026-10-23T16:30:00.000Z',
            },
          ],
        },
      ],
    });

    expect(availability.days.single.slots, hasLength(2));
  });
}
