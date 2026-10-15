import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_page.dart';

abstract final class AppRouter {
  static GoRouter create() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => const HomePage()),
      GoRoute(path: '/r/:token', builder: (_, _) => const HomePage()),
      GoRoute(path: '/admin/login', builder: (_, _) => const HomePage()),
    ],
  );
}
