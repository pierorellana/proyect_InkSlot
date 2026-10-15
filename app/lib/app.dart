import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/inkslot_theme.dart';

class InkSlotApp extends StatelessWidget {
  const InkSlotApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'InkSlot',
    theme: buildInkSlotTheme(),
    routerConfig: AppRouter.create(),
  );
}
