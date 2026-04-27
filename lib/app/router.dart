import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/storage_providers.dart';
import '../core/theme/app_colors.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/onboarding_loading_page.dart';
import '../features/onboarding/presentation/onboarding_ready_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/explore/presentation/category_detail_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/player/presentation/player_page.dart';
import '../features/player/presentation/preparation_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/paywall/presentation/paywall_page.dart';
import '../features/paywall/presentation/paywall_success_page.dart';
import 'home_shell.dart';

// Noms de routes — toujours utiliser ces constantes pour naviguer
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const onboardingLoading = '/onboarding-loading';
  static const onboardingReady = '/onboarding-ready';
  static const paywall = '/paywall';
  static const paywallSuccess = '/paywall-success';
  static const shell = '/shell';
  static const home = '/home';
  static const explore = '/explore';
  static const profile = '/profile';
  static const player = '/player/:sessionId';
  static const preparation = '/preparation/:sessionId';
  static const category = '/category/:categoryId';

  static String playerPath(String sessionId) => '/player/$sessionId';
  static String preparationPath(String sessionId) => '/preparation/$sessionId';
  static String categoryPath(String categoryId) => '/category/$categoryId';
}

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

    // ── Onboarding loading ────────────────────────────
    GoRoute(
      path: AppRoutes.onboardingLoading,
      builder: (context, state) => const OnboardingLoadingPage(),
    ),

    // ── Onboarding ready ──────────────────────────────
    GoRoute(
      path: AppRoutes.onboardingReady,
      builder: (context, state) => const OnboardingReadyPage(),
    ),

    // ── Paywall ───────────────────────────────────────
    GoRoute(
      path: AppRoutes.paywall,
      builder: (context, state) => const PaywallPage(),
    ),

    // ── Paywall success ───────────────────────────────
    GoRoute(
      path: AppRoutes.paywallSuccess,
      builder: (context, state) => const PaywallSuccessPage(),
    ),

    // ── Category detail (hors shell) ─────────────────
    GoRoute(
      path: AppRoutes.category,
      builder: (context, state) {
        final categoryId = state.pathParameters['categoryId']!;
        return CategoryDetailPage(categoryId: categoryId);
      },
    ),

    // ── Preparation (hors shell) ──────────────────────
    GoRoute(
      path: AppRoutes.preparation,
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        return PreparationPage(sessionId: sessionId);
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

    // ── Shell avec bottom nav (stack isolée par tab) ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const HomePage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.explore,
            builder: (context, state) => const ExplorePage(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ProfilePage(),
          ),
        ]),
      ],
    ),
  ],
);

/// Redirige vers onboarding ou home selon l'état local
class _SplashDecider extends ConsumerStatefulWidget {
  const _SplashDecider();

  @override
  ConsumerState<_SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends ConsumerState<_SplashDecider> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Petite pause pour le splash
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final done = ref.read(storageServiceProvider).isOnboardingDone;
    context.go(done ? AppRoutes.home : AppRoutes.onboarding);
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
