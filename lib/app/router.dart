import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../features/louane/presentation/louane_page.dart';
import 'home_shell.dart';
import 'splash_page.dart';

// Noms de routes — toujours utiliser ces constantes pour naviguer
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const onboardingLoading = '/onboarding-loading';
  static const onboardingReady = '/onboarding-ready';
  static const paywall = '/paywall';
  // Ouverture avec montée glissée (séance premium / profil)
  static const paywallSlide = '/paywall?from=premium';
  static const shell = '/shell';
  static const home = '/home';
  static const explore = '/explore';
  static const louane = '/louane';
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
      builder: (context, state) => const SplashPage(),
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
      pageBuilder: (context, state) {
        final slideUp = state.uri.queryParameters['from'] == 'premium';
        const page = PaywallPage();
        if (slideUp) {
          // Montée glissée + fondu doux (feuille modale)
          return CustomTransitionPage(
            key: state.pageKey,
            child: page,
            transitionDuration: const Duration(milliseconds: 420),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            transitionsBuilder: (context, animation, secondary, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(curved),
                child: FadeTransition(opacity: curved, child: child),
              );
            },
          );
        }
        // Onboarding : fondu doux identique à l'actuel
        return CustomTransitionPage(
          key: state.pageKey,
          child: page,
          transitionsBuilder: (context, animation, secondary, child) =>
              FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            child: child,
          ),
        );
      },
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
            path: AppRoutes.louane,
            builder: (context, state) => const LouanePage(),
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
