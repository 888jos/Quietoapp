import 'package:go_router/go_router.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/onboarding_loading_page.dart';
import '../features/onboarding/presentation/onboarding_ready_page.dart';
import '../features/onboarding/presentation/onboarding_breath_page.dart';
import '../features/onboarding/presentation/onboarding_trust_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/explore/presentation/category_detail_page.dart';
import '../features/explore/presentation/explore_page.dart';
import '../features/player/presentation/player_page.dart';
import '../features/player/presentation/preparation_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/paywall/presentation/paywall_page.dart';
import '../features/louane/presentation/louane_page.dart';
import 'home_shell.dart';
import 'page_transitions.dart';
import 'splash_page.dart';

// Noms de routes — toujours utiliser ces constantes pour naviguer
abstract final class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const onboardingLoading = '/onboarding-loading';
  static const onboardingReady = '/onboarding-ready';
  static const onboardingBreath = '/onboarding-breath';
  static const onboardingTrust = '/onboarding-trust';
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
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const SplashPage(),
      ),
    ),

    // ── Onboarding (fondu respirant entre chaque étape) ──
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingLoading,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingLoadingPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingReady,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingReadyPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingBreath,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingBreathPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingTrust,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingTrustPage(),
      ),
    ),

    // ── Paywall ───────────────────────────────────────
    // Depuis une séance premium : montée façon feuille modale.
    // En fin d'onboarding : fondu, dans la continuité des étapes.
    GoRoute(
      path: AppRoutes.paywall,
      pageBuilder: (context, state) {
        final slideUp = state.uri.queryParameters['from'] == 'premium';
        const page = PaywallPage();
        return slideUp
            ? QuietoTransitions.sheetPage(key: state.pageKey, child: page)
            : QuietoTransitions.fadePage(key: state.pageKey, child: page);
      },
    ),

    // ── Category detail (monte du bas, retour en fondu) ──
    GoRoute(
      path: AppRoutes.category,
      pageBuilder: (context, state) => QuietoTransitions.sheetPage(
        key: state.pageKey,
        fadeBack: true,
        child: CategoryDetailPage(
          categoryId: state.pathParameters['categoryId']!,
        ),
      ),
    ),

    // ── Preparation (on entre dans une séance) ────────
    GoRoute(
      path: AppRoutes.preparation,
      pageBuilder: (context, state) => QuietoTransitions.slidePage(
        key: state.pageKey,
        child: PreparationPage(sessionId: state.pathParameters['sessionId']!),
      ),
    ),

    // ── Player (moment immersif, monte du bas) ────────
    GoRoute(
      path: AppRoutes.player,
      pageBuilder: (context, state) => QuietoTransitions.sheetPage(
        key: state.pageKey,
        child: PlayerPage(sessionId: state.pathParameters['sessionId']!),
      ),
    ),

    // ── Shell avec bottom nav (stack isolée par tab) ──
    // Fondu croisé entre les onglets, état conservé.
    StatefulShellRoute(
      builder: (context, state, shell) => HomeShell(shell: shell),
      navigatorContainerBuilder: (context, shell, children) =>
          AnimatedBranchContainer(
            currentIndex: shell.currentIndex,
            children: children,
          ),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.explore,
              builder: (context, state) => const ExplorePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.louane,
              builder: (context, state) => const LouanePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
