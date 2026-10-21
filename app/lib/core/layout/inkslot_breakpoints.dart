enum InkSlotScreenClass { compact, tablet, desktop }

InkSlotScreenClass inkSlotScreenClassForWidth(double width) {
  if (width < 600) return InkSlotScreenClass.compact;
  if (width < 1024) return InkSlotScreenClass.tablet;
  return InkSlotScreenClass.desktop;
}

double adminPageMaxWidthFor(double width) {
  switch (inkSlotScreenClassForWidth(width)) {
    case InkSlotScreenClass.compact:
      return 640;
    case InkSlotScreenClass.tablet:
      return 860;
    case InkSlotScreenClass.desktop:
      return 1120;
  }
}
