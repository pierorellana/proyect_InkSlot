import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/app.dart';
import 'package:inkslot_app/features/public_booking/presentation/public_welcome_page.dart';

void main() {
  testWidgets('renders the InkSlot shell', (tester) async {
    await tester.pumpWidget(const InkSlotApp());

    expect(find.text('SALTAR INTRO'), findsOneWidget);

    await tester.tap(find.text('SALTAR INTRO'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(PublicWelcomePage), findsOneWidget);
    expect(find.text('Elegir fecha y hora'), findsOneWidget);
  });

  testWidgets('keeps the public entry point available while admin is guarded', (
    tester,
  ) async {
    await tester.pumpWidget(const InkSlotApp());

    expect(find.text('SALTAR INTRO'), findsOneWidget);
    expect(find.text('Ingresar al panel'), findsNothing);
  });
}
