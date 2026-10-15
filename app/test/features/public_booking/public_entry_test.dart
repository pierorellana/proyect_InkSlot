import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/app.dart';
import 'package:inkslot_app/core/router/app_router.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_entry_controller.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_splash_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_welcome_page.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_dates_placeholder.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('reduced-motion splash completes without waiting', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: ChangeNotifierProvider(
            create: (_) => PublicEntryController(),
            child: PublicSplashPage(onFinished: () => completed = true),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(completed, isTrue);
  });

  testWidgets('deep links skip the splash and render the private welcome', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildInkSlotTheme(),
        routerConfig: AppRouter.create(initialLocation: '/r/test-token'),
      ),
    );
    await tester.pump();

    expect(find.byType(PublicWelcomePage), findsOneWidget);
    expect(find.text('SALTAR INTRO'), findsNothing);

    await tester.ensureVisible(find.text('Elegir fecha y hora'));
    await tester.tap(find.text('Elegir fecha y hora'));
    await tester.pumpAndSettle();
    expect(find.byType(PublicDatesPlaceholder), findsOneWidget);
  });

  testWidgets('root skip action navigates to the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(const InkSlotApp());
    await tester.tap(find.text('SALTAR INTRO'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(PublicWelcomePage), findsOneWidget);
  });
}
