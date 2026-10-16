import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/features/public_booking/domain/public_appointment.dart';
import 'package:inkslot_app/features/public_booking/domain/public_confirmation.dart';

void main() {
  final json = <String, dynamic>{
    'status': 'confirmed',
    'syncStatus': 'pending',
    'startAt': '2026-10-20T15:00:00.000Z',
    'endAt': '2026-10-20T18:00:00.000Z',
    'timezone': 'America/Guayaquil',
  };

  test('parses UTC confirmation and appointment fields', () {
    final confirmation = PublicConfirmation.fromJson(json);
    final appointment = PublicAppointment.fromJson(json);

    expect(confirmation.startAt, DateTime.utc(2026, 10, 20, 15));
    expect(confirmation.endAt, DateTime.utc(2026, 10, 20, 18));
    expect(appointment.syncStatus, 'pending');
  });

  test('rejects malformed instants, statuses, and timezones', () {
    expect(
      () => PublicConfirmation.fromJson({...json, 'startAt': '2026-10-20'}),
      throwsFormatException,
    );
    expect(
      () => PublicConfirmation.fromJson({...json, 'syncStatus': 'queued'}),
      throwsFormatException,
    );
    expect(
      () => PublicConfirmation.fromJson({...json, 'timezone': 'not local'}),
      throwsFormatException,
    );
  });
}
