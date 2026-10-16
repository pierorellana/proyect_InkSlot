import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_splash_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_welcome_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_entry_controller.dart';
import 'package:provider/provider.dart';

import 'client_shots_support.dart';
import 'shot_helper.dart';

void main() {
  setUpAll(loadFonts);

  for (final ms in [900, 1800, 2700, 3300, 4300]) {
    testWidgets('splash $ms', (t) async {
      await shot(
        t,
        'c01-splash-$ms',
        ChangeNotifierProvider(
          create: (_) => PublicEntryController(),
          child: PublicSplashPage(onFinished: () {}),
        ),
        settle: Duration(milliseconds: ms),
      );
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  }

  Future<void> welcome(WidgetTester t, String name, ShotRepository repo,
      {Duration settle = const Duration(milliseconds: 1800)}) async {
    final c = shotController(repo);
    await shot(
      t,
      name,
      PublicWelcomePage(controller: c, token: 't', onChooseDate: () {}),
      settle: settle,
      after: (t) async {
        for (var i = 0; i < 20; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
      },
    );
    await t.pumpWidget(const SizedBox());
  }

  testWidgets('welcome', (t) => welcome(t, 'c02-welcome', ShotRepository()));
  testWidgets('vencido', (t) => welcome(t, 'c11-vencido',
      ShotRepository(reservationError: apiError('TOKEN_EXPIRED'))));
  testWidgets('cancelado', (t) => welcome(t, 'c12-cancelado',
      ShotRepository(reservationError: apiError('TOKEN_REVOKED'))));
  testWidgets('agendado', (t) => welcome(t, 'c18-agendado',
      ShotRepository(reservationError: apiError('ALREADY_BOOKED'))));
  testWidgets('sin_red', (t) => welcome(t, 'c13-sin-red',
      ShotRepository(reservationError: apiError('NETWORK_ERROR'))));
}
