import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/explore/presentation/category_detail_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/player/presentation/player_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/paywall/presentation/paywall_page.dart';
import 'home_shell.dart';

// Noms de routes — toujours utiliser ces constantes pour naviguer
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const paywall = '/paywall';
  static const shell = '/shell';
  static const home = '/home';
  static const explore = '/explore';
  static const profile = '/profile';
  static const player = '/player/:sessionId';
  static const category = '/category/:categoryId';

  static String playerPath(String sessionId) => '/player/$sessionId';
  static String categoryPath(String categoryId) => '/category/$categoryId';
}

final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: false,
  routes: [
    // ── Splash ────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const _SplashDecider(),
    ),

    // ── Onboarding ────────────────────────────────────
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),

    // ── Paywall ───────────────────────────────────────
    GoRoute(
      path: AppRoutes.paywall,
      builder: (context, state) => const PaywallPage(),
    ),

    // ── Category detail (hors shell) ─────────────────
    GoRoute(
      path: AppRoutes.category,
      builder: (context, state) {
        final categoryId = state.pathParameters['categoryId']!;
        return CategoryDetailPage(categoryId: categoryId);
      },
    ),

    // ── Player (hors shell) ───────────────────────────
    GoRoute(
      path: AppRoutes.player,
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return PlayerPage(sessionId: sessionId);
      },
    ),

    // ── Shell avec bottom nav ─────────────────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: AppRoutes.explore,
          builder: (context, state) => const ExplorePage(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfilePage(),
        ),
      ],
    ),
  ],
);

/// Redirige vers onboarding ou home selon l'état local
class _SplashDecider extends StatefulWidget {
  const _SplashDecider();

  @override
  State<_SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<_SplashDecider> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Petite pause pour le splash
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      ),
    );
  }
}
