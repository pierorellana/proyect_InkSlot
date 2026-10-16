import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/network/api_client.dart';
import 'package:inkslot_app/features/appointments/data/admin_appointments_repository.dart';
import 'package:inkslot_app/features/appointments/domain/admin_appointment.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_controller.dart';
import 'package:inkslot_app/features/appointments/presentation/admin_appointments_page.dart';
import 'package:inkslot_app/features/requests/data/booking_requests_repository.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/domain/booking_request_status.dart';
import 'package:inkslot_app/features/requests/presentation/booking_request_detail_page.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_controller.dart';
import 'package:inkslot_app/features/requests/presentation/booking_requests_page.dart';
import 'package:inkslot_app/features/requests/presentation/widgets/request_action_sheet.dart';

import 'shot_helper.dart';

void main() {
  setUpAll(loadFonts);

  testWidgets('requests list', (t) async {
    final c = BookingRequestsController(_ReqRepo());
    await shot(t, 'r1-list', _S(BookingRequestsPage(controller: c)));
  });

  testWidgets('requests loading', (t) async {
    final c = BookingRequestsController(_ReqRepo(delay: true));
    await shot(
      t,
      'r2-loading',
      _S(BookingRequestsPage(controller: c)),
      settle: const Duration(milliseconds: 200),
    );
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('requests empty', (t) async {
    final c = BookingRequestsController(_ReqRepo(empty: true));
    await shot(t, 'r3-empty', _S(BookingRequestsPage(controller: c)));
  });

  for (final entry in {
    'pending': BookingRequestStatus.pending,
    'expired': BookingRequestStatus.expired,
    'booked': BookingRequestStatus.booked,
  }.entries) {
    testWidgets('detail ${entry.key}', (t) async {
      final c = BookingRequestsController(_ReqRepo(detailStatus: entry.value));
      await shot(
        t,
        'r4-detail-${entry.key}',
        _S(BookingRequestDetailPage(controller: c, requestId: 'r1')),
      );
    });
  }

  testWidgets('confirm sheet', (t) async {
    final r = (await _ReqRepo().detail('r1')).request;
    await shot(
      t,
      'r5-sheet',
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            decoration: BoxDecoration(
              color: const Color(0xFF161618),
              borderRadius: BorderRadius.circular(38),
            ),
            child: RequestActionSheet(action: RequestAction.close, request: r),
          ),
        ),
      ),
    );
  });

  testWidgets('appointments', (t) async {
    final c = AdminAppointmentsController(_ApptRepo());
    await shot(t, 'a1-list', _S(AdminAppointmentsPage(controller: c)));
  });

  testWidgets('appointments empty', (t) async {
    final c = AdminAppointmentsController(_ApptRepo(empty: true));
    await shot(t, 'a2-empty', _S(AdminAppointmentsPage(controller: c)));
  });
}

BookingRequest _req(String id, String name, BookingRequestStatus s) =>
    BookingRequest(
      id: id,
      client: BookingRequestClient(
        id: 'c$id',
        name: name,
        contactChannel: ContactChannel.whatsapp,
        contactValue: '+593 98 *** 1170',
      ),
      paymentReference: 'Transf. 0031',
      depositVerified: true,
      durationMinutes: 180,
      status: s,
      minDate: null,
      maxDate: null,
      allowedWeekdays: const [6],
      allowedWindows: null,
      createdAt: DateTime.utc(2026, 10, 12),
    );

class _ReqRepo extends BookingRequestsRepository {
  _ReqRepo({this.empty = false, this.delay = false, this.detailStatus})
    : super(_Noop());
  final bool empty;
  final bool delay;
  final BookingRequestStatus? detailStatus;

  @override
  Future<BookingRequestPage> list({
    BookingRequestStatus? status,
    String? cursor,
  }) async {
    if (delay) await Future<void>.delayed(const Duration(seconds: 1));
    if (empty) return const BookingRequestPage(items: [], nextCursor: null);
    return BookingRequestPage(
      items: [
        _req('r1', 'Daniela Paz', BookingRequestStatus.pending),
        _req('r2', 'Valentina Rosero', BookingRequestStatus.pending),
        _req('r3', 'Mateo Andrade', BookingRequestStatus.pending),
      ],
      nextCursor: null,
    );
  }

  @override
  Future<BookingRequestDetail> detail(String id) async {
    final s = detailStatus ?? BookingRequestStatus.pending;
    final now = DateTime.now().toUtc();
    return BookingRequestDetail(
      request: _req(id, 'Camila Ortiz', s),
      currentLink: s == BookingRequestStatus.pending
          ? CurrentBookingLink(
              status: BookingLinkStatus.active,
              expiresAt: now.add(const Duration(hours: 31)),
            )
          : null,
      audit: [
        BookingRequestAuditEntry(
          action: 'token_renewed',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
        BookingRequestAuditEntry(
          action: 'created',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ],
    );
  }
}

class _ApptRepo extends AdminAppointmentsRepository {
  _ApptRepo({this.empty = false}) : super(_Noop());
  final bool empty;

  @override
  Future<AdminAppointmentPage> list({
    AdminAppointmentStatus status = AdminAppointmentStatus.confirmed,
    String? cursor,
  }) async {
    if (empty) return const AdminAppointmentPage(items: [], nextCursor: null);
    AdminAppointment a(String id, String n, int d, int h, int mins,
            AdminAppointmentSyncStatus sync) =>
        AdminAppointment(
          id: id,
          clientName: n,
          startAt: DateTime(2026, 10, d, h).toUtc(),
          endAt: DateTime(2026, 10, d, h).add(Duration(minutes: mins)).toUtc(),
          durationMinutes: mins,
          status: status,
          syncStatus: sync,
          version: 1,
        );
    return AdminAppointmentPage(
      items: [
        a('1', 'Joaquín Vera', 16, 11, 90, AdminAppointmentSyncStatus.synced),
        a('2', 'Sofía Paredes', 17, 14, 240, AdminAppointmentSyncStatus.failed),
        a('3', 'Andrés Cueva', 20, 10, 180, AdminAppointmentSyncStatus.synced),
        a('4', 'Lucía Torres', 22, 16, 120, AdminAppointmentSyncStatus.pending),
      ],
      nextCursor: null,
    );
  }
}

class _S extends StatelessWidget {
  const _S(this.child);
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(body: child);
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
