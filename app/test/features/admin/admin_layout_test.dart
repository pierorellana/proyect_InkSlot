import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/features/admin/presentation/admin_layout.dart';

void main() {
  testWidgets('uses compact spacing below the mobile admin header', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text('${adminPageTopInset(context)}'),
        ),
      ),
    );

    expect(find.text('20.0'), findsOneWidget);
  });

  testWidgets('keeps a restrained inset on desktop admin pages', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Text('${adminPageTopInset(context)}'),
        ),
      ),
    );

    expect(find.text('28.0'), findsOneWidget);
  });
}
