import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/theme/inkslot_theme.dart';
import 'package:inkslot_app/features/public_booking/domain/public_availability.dart';
import 'package:inkslot_app/features/public_booking/presentation/widgets/public_time_wheel.dart';

void main() {
  final slots = <AvailabilitySlot>[
    _slot(15),
    _slot(16),
    _slot(17),
    _slot(18),
  ];

  Widget app(Widget child, {bool reduceMotion = true}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: MaterialApp(
      theme: buildInkSlotTheme(),
      home: Scaffold(body: child),
    ),
  );

  testWidgets('focuses the middle slot and chooses it from the pill', (
    tester,
  ) async {
    AvailabilitySlot? chosen;
    await tester.pumpWidget(
      app(
        PublicTimeWheel(
          slots: slots,
          timezone: 'America/Guayaquil',
          selectedSlot: null,
          onSelected: (slot) => chosen = slot,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 de 4 HORARIOS LIBRES'.toUpperCase()), findsOneWidget);
    expect(find.text('HASTA'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    await tester.tap(find.text('12:00'));
    expect(chosen, same(slots[2]));
  });

  testWidgets('moves with taps on dots, arrows and the keyboard', (
    tester,
  ) async {
    AvailabilitySlot? chosen;
    await tester.pumpWidget(
      app(
        PublicTimeWheel(
          slots: slots,
          timezone: 'America/Guayaquil',
          selectedSlot: slots.first,
          onSelected: (slot) => chosen = slot,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 de 4 HORARIOS LIBRES'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('11:00'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 4 HORARIOS LIBRES'.toUpperCase()), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('3 de 4 HORARIOS LIBRES'.toUpperCase()), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('2 de 4 HORARIOS LIBRES'.toUpperCase()), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(chosen, same(slots[1]));
  });

  testWidgets('animated wheel settles on the tapped slot', (tester) async {
    await tester.pumpWidget(
      app(
        PublicTimeWheel(
          slots: slots,
          timezone: 'America/Guayaquil',
          selectedSlot: slots.first,
          onSelected: (_) {},
        ),
        reduceMotion: false,
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('11:00'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 de 4 HORARIOS LIBRES'.toUpperCase()), findsOneWidget);
  });

  testWidgets('empty slot lists render no fake time', (tester) async {
    await tester.pumpWidget(
      app(
        const PublicTimeWheel(
          slots: <AvailabilitySlot>[],
          timezone: 'UTC',
          selectedSlot: null,
          onSelected: _noop,
        ),
      ),
    );
    expect(find.text('10:00'), findsNothing);
    expect(find.textContaining('HORARIOS LIBRES'), findsNothing);
  });
}

AvailabilitySlot _slot(int hour) => AvailabilitySlot(
  startAt: DateTime.utc(2026, 10, 23, hour),
  endAt: DateTime.utc(2026, 10, 23, hour + 3),
);

void _noop(AvailabilitySlot slot) {}
