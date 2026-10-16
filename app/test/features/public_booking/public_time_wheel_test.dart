import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/presentation/widgets/public_time_wheel.dart';

void main() {
  final slots = <AvailabilitySlot>[_slot(15), _slot(16), _slot(17)];

  testWidgets('supports tap and arrow selection with study timezone labels', (
    tester,
  ) async {
    AvailabilitySlot? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: PublicTimeWheel(
          slots: slots,
          timezone: 'America/Guayaquil',
          selectedSlot: slots.first,
          onSelected: (slot) => selected = slot,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('10:00'), findsWidgets);
    await tester.tap(find.text('11:00').first);
    await tester.pumpAndSettle();
    expect(selected, same(slots[1]));

    await tester.tap(find.byTooltip('Horario anterior'));
    await tester.pumpAndSettle();
    expect(selected, same(slots.first));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(selected, same(slots[1]));
  });

  testWidgets('reduced motion keeps the wheel selectable and semantic', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    AvailabilitySlot? selected;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          theme: buildInkSlotTheme(),
          home: PublicTimeWheel(
            slots: slots,
            timezone: 'America/Guayaquil',
            selectedSlot: slots.first,
            onSelected: (slot) => selected = slot,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Siguiente horario'));
    await tester.pump();

    expect(selected, same(slots[1]));
    expect(find.bySemanticsLabel('11:00, seleccionado'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('empty slot lists render no fake time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInkSlotTheme(),
        home: const PublicTimeWheel(
          slots: <AvailabilitySlot>[],
          timezone: 'UTC',
          selectedSlot: null,
          onSelected: _noop,
        ),
      ),
    );
    expect(find.text('10:00'), findsNothing);
    expect(find.byType(ListWheelScrollView), findsNothing);
  });
}

AvailabilitySlot _slot(int hour) => AvailabilitySlot(
  startAt: DateTime.utc(2026, 10, 23, hour),
  endAt: DateTime.utc(2026, 10, 23, hour + 1),
);

void _noop(AvailabilitySlot slot) {}
