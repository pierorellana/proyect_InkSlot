import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';

void main() {
  test('builds the appointments endpoint with status and cursor', () async {
    final api = RecordingApiClient(
      result: <String, dynamic>{'items': <dynamic>[], 'nextCursor': null},
    );
    final repository = AdminAppointmentsRepository(api);

    final page = await repository.list(
      status: AdminAppointmentStatus.noShow,
      cursor: 'opaque/cursor',
    );

    expect(page.items, isEmpty);
    expect(
      api.lastGetPath,
      '/admin/appointments?status=no_show&cursor=opaque%2Fcursor',
    );
  });

  test('decodes appointment and pagination fields', () async {
    final api = RecordingApiClient(
      result: <String, dynamic>{
        'items': [_appointmentJson()],
        'nextCursor': 'next-page',
      },
    );
    final page = await AdminAppointmentsRepository(api).list();

    expect(page.nextCursor, 'next-page');
    expect(page.items.single.clientName, 'Ana Ink');
    expect(page.items.single.status, AdminAppointmentStatus.confirmed);
    expect(page.items.single.syncStatus, AdminAppointmentSyncStatus.synced);
    expect(page.items.single.durationMinutes, 120);
  });

  test('rejects unknown appointment statuses', () async {
    final json = _appointmentJson()..['status'] = 'rescheduled';
    final api = RecordingApiClient(
      result: <String, dynamic>{
        'items': [json],
        'nextCursor': null,
      },
    );

    await expectLater(
      AdminAppointmentsRepository(api).list(),
      throwsA(isA<FormatException>()),
    );
  });
}

class RecordingApiClient implements ApiClient {
  RecordingApiClient({required this.result});

  final Map<String, dynamic> result;
  String? lastGetPath;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    lastGetPath = path;
    return result;
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => result;
}

Map<String, dynamic> _appointmentJson() => <String, dynamic>{
  'id': 'appointment-1',
  'client': {'name': 'Ana Ink'},
  'startAt': '2026-10-20T15:00:00.000Z',
  'endAt': '2026-10-20T17:00:00.000Z',
  'durationMinutes': 120,
  'status': 'confirmed',
  'syncStatus': 'synced',
  'version': 1,
};
