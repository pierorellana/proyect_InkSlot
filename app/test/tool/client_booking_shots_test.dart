import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/widgets/inkslot_kit.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_dates_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_result_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_review_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_reservation_controller.dart';

import 'client_shots_support.dart';
import 'shot_helper.dart';

const _ms = Duration(milliseconds: 1500);

Future<void> run(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadFonts);

  final now = DateTime.now();
  Future<void> dates(
    WidgetTester t,
    String name,
    ShotRepository repo, {
    Future<void> Function(WidgetTester, PublicReservationController)? after,
    Duration settle = _ms,
  }) async {
    final c = shotController(repo);
    await shot(
      t,
      name,
      PublicDatesPage(controller: c, token: 't', onReview: () {}),
      settle: settle,
      after: (t) async {
        await run(t, 1000);
        if (after != null) await after(t, c);
      },
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 31));
  }

  Future<void> toTimes(WidgetTester t, PublicReservationController c) async {
    c.selectDate(c.availability!.days.first.date);
    await run(t, 400);
    await t.tap(find.textContaining('Ver horarios del'));
    await run(t, 100);
    await run(t, 1200);
  }

  testWidgets(
    'calendario vacio',
    (t) => dates(
      t,
      'c03-calendario-vacio',
      ShotRepository(emptyAvailability: true),
    ),
  );
  testWidgets(
    'calendario dia',
    (t) => dates(
      t,
      'c04-calendario-dia',
      ShotRepository(),
      after: (t, c) async {
        c.selectDate(c.availability!.days.first.date);
        await run(t, 100);
        await run(t, 900);
      },
    ),
  );
  testWidgets(
    'calendario cargando',
    (t) => dates(
      t,
      'c03b-calendario-cargando',
      ShotRepository(availabilityDelay: const Duration(seconds: 30)),
      settle: const Duration(milliseconds: 1200),
    ),
  );
  testWidgets('horarios cargando', (t) async {
    final repo = ShotRepository();
    await dates(
      t,
      'c05-horarios-cargando',
      repo,
      after: (t, c) async {
        await toTimes(t, c);
        repo.availabilityDelay = const Duration(seconds: 30);
        c.retryAvailability();
        await run(t, 900);
      },
    );
  });
  testWidgets(
    'horarios',
    (t) => dates(t, 'c06-horarios', ShotRepository(), after: toTimes),
  );
  testWidgets(
    'horarios rueda',
    (t) => dates(
      t,
      'c07-horarios-rueda',
      ShotRepository(),
      after: (t, c) async {
        await toTimes(t, c);
        await t.tap(find.byType(InkSlotIconButton).last);
        await run(t, 100);
        await run(t, 900);
      },
    ),
  );
  testWidgets(
    'agenda no verificable',
    (t) => dates(
      t,
      'c15-agenda-no-verificable',
      ShotRepository(availabilityError: apiError('CALENDAR_UNAVAILABLE')),
    ),
  );
  testWidgets(
    'sin red calendario',
    (t) => dates(
      t,
      'c13b-calendario-sin-red',
      ShotRepository(availabilityError: apiError('NETWORK_ERROR')),
    ),
  );

  Future<PublicReservationController> selected(ShotRepository repo) async {
    final c = shotController(repo);
    await c.loadReservation('t');
    final base = DateTime(now.year, now.month);
    await c.loadAvailability('t', base, DateTime(now.year, now.month + 1, 0));
    c.selectDate(c.availability!.days.first.date);
    c.selectSlot(c.selectedDay!.slots[3]);
    return c;
  }

  Future<void> review(
    WidgetTester t,
    String name,
    ShotRepository repo, {
    Future<void> Function(WidgetTester)? after,
  }) async {
    final c =
        await t.runAsync(() => selected(repo)) as PublicReservationController;
    await shot(
      t,
      name,
      PublicReviewPage(
        token: 't',
        controller: c,
        onBack: () {},
        onConfirmed: () {},
      ),
      after: after,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 31));
  }

  testWidgets('revision', (t) => review(t, 'c08-revision', ShotRepository()));
  testWidgets(
    'revision tilt',
    (t) => review(
      t,
      'c08b-revision-tilt',
      ShotRepository(),
      after: (t) async {
        final g = await t.createGesture(kind: PointerDeviceKind.mouse);
        await g.addPointer(location: const Offset(60, 200));
        await g.moveTo(const Offset(340, 180));
        await run(t, 400);
      },
    ),
  );
  testWidgets(
    'confirmando',
    (t) => review(
      t,
      'c09-confirmando',
      ShotRepository(confirmDelay: const Duration(seconds: 30)),
      after: (t) async {
        await t.tap(find.text('Confirmar cita'));
        await run(t, 600);
      },
    ),
  );
  testWidgets(
    'conflicto',
    (t) => review(
      t,
      'c16-conflicto-409',
      ShotRepository(confirmError: apiError('SLOT_UNAVAILABLE', status: 409)),
      after: (t) async {
        await t.tap(find.text('Confirmar cita'));
        await run(t, 100);
        await run(t, 1200);
      },
    ),
  );
  testWidgets(
    'revision error agenda',
    (t) => review(
      t,
      'c08c-revision-error',
      ShotRepository(confirmError: apiError('CALENDAR_UNAVAILABLE')),
      after: (t) async {
        await t.tap(find.text('Confirmar cita'));
        await run(t, 100);
        await run(t, 1200);
      },
    ),
  );

  Future<void> success(
    WidgetTester t,
    String name,
    ShotRepository repo, {
    Duration at = const Duration(milliseconds: 2800),
  }) async {
    final c =
        await t.runAsync(() async {
              final c = await selected(repo);
              await c.confirmSelected('t');
              return c;
            })
            as PublicReservationController;
    await shot(
      t,
      name,
      PublicResultPage(token: 't', controller: c, onReturnToDates: () {}),
      settle: at,
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 31));
  }

  testWidgets('exito', (t) => success(t, 'c10-exito', ShotRepository()));
  testWidgets(
    'exito stamp',
    (t) => success(
      t,
      'c10b-exito-stamp',
      ShotRepository(),
      at: const Duration(milliseconds: 500),
    ),
  );
  testWidgets(
    'sync pendiente',
    (t) =>
        success(t, 'c17-sync-pendiente', ShotRepository(syncStatus: 'pending')),
  );
}
