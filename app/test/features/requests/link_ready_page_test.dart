import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/requests/domain/booking_request.dart';
import 'package:inkslot_app/features/requests/presentation/link_ready_page.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    theme: buildInkSlotTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: Scaffold(body: child),
  );

  void usePhoneView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows, copies, and shares the ephemeral link', (tester) async {
    usePhoneView(tester);
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      host(
        LinkReadyPage(
          link: LinkReadyData(
            path: '/r/secret-token',
            expiresAt: DateTime.now().add(const Duration(hours: 48)),
          ),
          clientName: 'Daniela Mora',
          durationMinutes: 180,
        ),
      ),
    );

    expect(find.textContaining('Enlace listo para'), findsOneWidget);
    expect(find.textContaining('Daniela.'), findsOneWidget);
    expect(find.textContaining('/r/secret-token'), findsOneWidget);
    expect(find.text('Vence en 48 h · 3 h · un solo uso'), findsOneWidget);

    await tester.tap(find.text('Copiar enlace'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Copiado'), findsOneWidget);
    expect(find.text('Enlace copiado'), findsOneWidget);
    expect(copied, hasLength(1));

    await tester.tap(find.text('Compartir'));
    await tester.pumpAndSettle();
    expect(find.text('Compartir con Daniela'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('Instagram'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'uses a safe callback instead of putting the token in navigation',
    (tester) async {
      usePhoneView(tester);
      var backed = false;
      await tester.pumpWidget(
        host(
          LinkReadyPage(
            link: LinkReadyData(
              path: '/r/another-secret',
              expiresAt: DateTime.utc(2026, 10, 19),
            ),
            onBack: () => backed = true,
          ),
        ),
      );

      expect(find.textContaining('tu cliente.'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Cerrar'));
      expect(backed, isTrue);
    },
  );
}
