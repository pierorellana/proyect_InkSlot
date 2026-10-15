import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/core/widgets/inkslot_logo.dart';
import 'package:inkslot_app/core/widgets/inkslot_mono_label.dart';
import 'package:inkslot_app/core/widgets/inkslot_primary_button.dart';

void main() {
  Widget harness(Widget child) => MaterialApp(
    theme: buildInkSlotTheme(),
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('logo exposes an accessible image label', (tester) async {
    await tester.pumpWidget(harness(const InkSlotLogo()));

    expect(find.bySemanticsLabel('Logo de InkSlot'), findsOneWidget);
  });

  testWidgets('mono label uses uppercase text and mono typography', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const InkSlotMonoLabel('reserva abierta')));

    final text = tester.widget<Text>(find.text('RESERVA ABIERTA'));
    expect(text.style?.fontFamily, 'Geist Mono');
    expect(text.style?.letterSpacing, 1.32);
  });

  testWidgets('primary button keeps a tactile target and invokes callback', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      harness(
        InkSlotPrimaryButton(
          label: 'Elegir fecha',
          onPressed: () => pressed = true,
        ),
      ),
    );

    expect(tester.getSize(find.byType(InkSlotPrimaryButton)).height, 56);
    await tester.tap(find.text('Elegir fecha'));
    expect(pressed, isTrue);
  });
}
