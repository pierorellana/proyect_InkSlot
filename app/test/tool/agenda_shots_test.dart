import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/agenda/data/agenda_repository.dart';
import 'package:inkslot_app/features/agenda/domain/availability.dart';
import 'package:inkslot_app/features/agenda/domain/calendar_status.dart';
import 'package:inkslot_app/features/agenda/presentation/admin_agenda_page.dart';
import 'package:inkslot_app/features/agenda/presentation/agenda_controller.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointment_detail_controller.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointment_detail_page.dart';

import 'shot_helper.dart';

void main() {
  setUpAll(loadFonts);

  for (final state in CalendarConnectionState.values) {
    testWidgets('agenda ${state.name}', (t) async {
      final c = AgendaController(_AgendaRepo(state));
      await shot(
        t,
        'g1-agenda-${state.name}',
        _S(AdminAgendaPage(controller: c)),
      );
    });
  }

  testWidgets('agenda block sheet', (t) async {
    final c = AgendaController(_AgendaRepo(CalendarConnectionState.connected));
    await shot(
      t,
      'g2-block-sheet',
      _S(AdminAgendaPage(controller: c)),
      after: (t) async {
        await t.tap(find.text('+ Agregar'));
        await t.pump(const Duration(milliseconds: 800));
      },
    );
  });

  for (final sync in AdminAppointmentSyncStatus.values) {
    testWidgets('detail ${sync.name}', (t) async {
      final c = AdminAppointmentDetailController(_ApptRepo(sync));
      await shot(
        t,
        'g3-detail-${sync.name}',
        _S(AdminAppointmentDetailPage(controller: c, appointmentId: 'a1')),
      );
    });
  }

  testWidgets('detail reschedule sheet', (t) async {
    final c = AdminAppointmentDetailController(
      _ApptRepo(AdminAppointmentSyncStatus.synced),
    );
    await shot(
      t,
      'g4-reschedule',
      _S(AdminAppointmentDetailPage(controller: c, appointmentId: 'a1')),
      after: (t) async {
        await t.tap(find.text('Reprogramar'));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 900));
      },
    );
  });

  testWidgets('detail cancel sheet', (t) async {
    final c = AdminAppointmentDetailController(
      _ApptRepo(AdminAppointmentSyncStatus.synced),
    );
    await shot(
      t,
      'g5-cancel',
      _S(AdminAppointmentDetailPage(controller: c, appointmentId: 'a1')),
      after: (t) async {
        await t.tap(find.text('Cancelar cita'));
        await t.pump(const Duration(milliseconds: 100));
        await t.pump(const Duration(milliseconds: 900));
      },
    );
  });
}

class _Noop implements ApiClient {
  @override
  Future<Map<String, dynamic>> getJson(String path) async => {};
  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async => {};
}

class _AgendaRepo extends AgendaRepository {
  _AgendaRepo(this.state) : super(_Noop());
  final CalendarConnectionState state;

  @override
  Future<CalendarStatus> calendarStatus() async =>
      CalendarStatus(state: state, calendarName: 'Citas estudio');

  @override
  Future<AdminAvailability?> availability() async => AdminAvailability(
    timezone: 'America/Guayaquil',
    slotStepMinutes: 30,
    bufferMinutes: 15,
    minimumNoticeHours: 24,
    horizonDays: 60,
    weeklyWindows: [
      for (final d in [2, 3, 4, 5, 6])
        WeeklyWindow(weekday: d, startLocal: '10:00', endLocal: '20:00'),
    ],
  );

  @override
  Future<List<AvailabilityBlock>> blocks() async => [
    AvailabilityBlock(
      id: 'b1',
      reason: 'Vacaciones',
      startAt: DateTime(2026, 12, 21),
      endAt: DateTime(2026, 12, 29),
    ),
    AvailabilityBlock(
      id: 'b2',
      reason: 'Feriado',
      startAt: DateTime(2026, 10, 31),
      endAt: DateTime(2026, 11, 1),
    ),
  ];
}

class _ApptRepo extends AdminAppointmentsRepository {
  _ApptRepo(this.sync) : super(_Noop());
  final AdminAppointmentSyncStatus sync;

  @override
  Future<AdminAppointmentDetail> detail(String id) async =>
      AdminAppointmentDetail(
        id: id,
        client: const AdminAppointmentClient(
          name: 'Andrés Cueva',
          contactValue: '@andres.cv',
        ),
        startAt: DateTime(2026, 10, 20, 10).toUtc(),
        endAt: DateTime(2026, 10, 20, 13).toUtc(),
        durationMinutes: 180,
        status: AdminAppointmentStatus.confirmed,
        syncStatus: sync,
        version: 1,
      );

  @override
  Future<AdminAvailability?> availability() async => AdminAvailability(
    timezone: 'America/Guayaquil',
    slotStepMinutes: 30,
    bufferMinutes: 15,
    minimumNoticeHours: 24,
    horizonDays: 60,
    weeklyWindows: [
      for (final d in [0, 1, 2, 3, 4, 5, 6])
        WeeklyWindow(weekday: d, startLocal: '10:00', endLocal: '20:00'),
    ],
  );
}

class _S extends StatelessWidget {
  const _S(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
