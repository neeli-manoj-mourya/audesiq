import 'package:go_router/go_router.dart';
import '../models/movie.dart';
import '../screens/splash_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/search_screen.dart';
import '../screens/player_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/player',
        builder: (context, state) {
          final movie = state.extra as Movie;
          return PlayerScreen(movie: movie);
        },
      ),
    ],
  );
}
