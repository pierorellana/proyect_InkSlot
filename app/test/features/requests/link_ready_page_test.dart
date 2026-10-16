import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/presentation/link_ready_page.dart';

void main() {
  testWidgets('shows, copies, and safely shares the ephemeral link', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: Scaffold(
          body: LinkReadyPage(
            link: LinkReadyData(
              path: '/r/secret-token',
              expiresAt: DateTime.utc(2026, 10, 18, 12),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tu enlace está listo.'), findsOneWidget);
    expect(find.textContaining('/r/secret-token'), findsOneWidget);
    expect(find.textContaining('Vence 18/10'), findsOneWidget);

    await tester.ensureVisible(find.text('Copiar enlace'));
    await tester.tap(find.text('Copiar enlace'));
    await tester.pumpAndSettle();

    expect(find.text('Copiado'), findsOneWidget);
  });

  testWidgets(
    'uses a safe callback instead of putting the token in navigation',
    (tester) async {
      var backed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInkSlotTheme(),
          home: Scaffold(
            body: LinkReadyPage(
              link: LinkReadyData(
                path: '/r/another-secret',
                expiresAt: DateTime.utc(2026, 10, 19),
              ),
              onBack: () => backed = true,
            ),
          ),
        ),
      );

      await tester.ensureVisible(find.text('Volver a solicitudes'));
      await tester.tap(find.text('Volver a solicitudes'));
      expect(backed, isTrue);
    },
  );
}
