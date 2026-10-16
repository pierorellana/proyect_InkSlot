import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkslot_app/features/public_booking/presentation/widgets/flash_mosaic.dart';

void main() {
  testWidgets('renders three mosaic columns in the mobile viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: FlashMosaic())),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final row = tester.widget<Row>(
      find.byKey(const ValueKey('flash-mosaic-columns')),
    );

    expect(row.children, hasLength(5));
    expect(row.children.whereType<Expanded>(), hasLength(3));
    expect(row.children.whereType<SizedBox>(), hasLength(2));
  });
}
