import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/home/presentation/home_page.dart';
import '../../features/public_booking/presentation/public_dates_placeholder.dart';
import '../../features/public_booking/presentation/public_entry_controller.dart';
import '../../features/public_booking/presentation/public_splash_page.dart';
import '../../features/public_booking/presentation/public_welcome_page.dart';

abstract final class AppRouter {
  static GoRouter create({String initialLocation = '/'}) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final router = GoRouter.of(context);
          return ChangeNotifierProvider(
            create: (_) => PublicEntryController(),
            child: PublicSplashPage(
              onFinished: () => router.go('/r/demo-token'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/r/:token',
        builder: (context, state) => PublicWelcomePage(
          token: state.pathParameters['token'] ?? '',
          onChooseDate: () =>
              context.go('/r/${state.pathParameters['token'] ?? ''}/dates'),
        ),
      ),
      GoRoute(
        path: '/r/:token/dates',
        builder: (_, _) => const PublicDatesPlaceholder(),
      ),
      GoRoute(path: '/admin/login', builder: (_, _) => const HomePage()),
    ],
  );
}
