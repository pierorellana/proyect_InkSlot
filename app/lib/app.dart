import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/theme/inkslot_theme.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/admin_session_controller.dart';

class InkSlotApp extends StatefulWidget {
  const InkSlotApp({super.key});

  @override
  State<InkSlotApp> createState() => _InkSlotAppState();
}

class _InkSlotAppState extends State<InkSlotApp> {
  late final HttpApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final AdminSessionController _sessionController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _apiClient = HttpApiClient();
    _authRepository = AuthRepository(_apiClient);
    _sessionController = AdminSessionController(_authRepository);
    _sessionController.restore();
    _router = AppRouter.create(sessionController: _sessionController);
  }

  @override
  void dispose() {
    _router.dispose();
    _sessionController.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: _sessionController,
    child: MaterialApp.router(
      title: 'InkSlot',
      theme: buildInkSlotTheme(),
      routerConfig: _router,
    ),
  );
}
