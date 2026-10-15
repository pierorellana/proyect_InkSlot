import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/app.dart';

void main() {
  testWidgets('renders the InkSlot shell', (tester) async {
    await tester.pumpWidget(const InkSlotApp());

    expect(find.text('InkSlot'), findsOneWidget);
    expect(find.text('Bootstrap local'), findsOneWidget);
  });
}
