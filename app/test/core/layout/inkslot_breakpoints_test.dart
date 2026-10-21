import 'package:flutter_test/flutter_test.dart';
import 'package:inkslot_app/core/layout/inkslot_breakpoints.dart';

void main() {
  test('classifies compact, tablet, and desktop widths', () {
    expect(inkSlotScreenClassForWidth(390), InkSlotScreenClass.compact);
    expect(inkSlotScreenClassForWidth(600), InkSlotScreenClass.tablet);
    expect(inkSlotScreenClassForWidth(1023.99), InkSlotScreenClass.tablet);
    expect(inkSlotScreenClassForWidth(1024), InkSlotScreenClass.desktop);
  });

  test('keeps page widths bounded by screen class', () {
    expect(adminPageMaxWidthFor(390), 640);
    expect(adminPageMaxWidthFor(768), 860);
    expect(adminPageMaxWidthFor(1280), 1120);
  });
}
