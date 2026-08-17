import 'package:go_router/go_router.dart';
import '../features/onboarding/presentation/onboarding_comprehension_page.dart';
import '../features/onboarding/presentation/onboarding_connexion_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/onboarding/presentation/onboarding_loading_page.dart';
import '../features/onboarding/presentation/onboarding_ready_page.dart';
import '../features/onboarding/presentation/onboarding_health_page.dart';
import '../features/onboarding/presentation/onboarding_breath_page.dart';
import '../features/onboarding/presentation/onboarding_trust_page.dart';
import '../features/home/presentation/home_page.dart';
import '../features/explore/presentation/category_detail_page.dart';
import '../features/player/presentation/lancement_page.dart';
import '../features/player/presentation/player_page.dart';
import '../features/player/presentation/preparation_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/paywall/presentation/paywall_page.dart';
import '../features/louane/presentation/louane_page.dart';
import '../features/parcours/presentation/parcours_creation_page.dart';
import '../features/parcours/presentation/parcours_page.dart';
import 'home_shell.dart';
import 'page_transitions.dart';
import 'splash_page.dart';

// Noms de routes — toujours utiliser ces constantes pour naviguer
abstract final class AppRoutes {
  static const splash = '/';
  // Première étape : créer son compte (Apple/Google), jamais bloquant.
  static const onboardingConnexion = '/onboarding-connexion';
  static const onboarding = '/onboarding';
  // Fin de questionnaire fusionnée (kAccueilLouaneOnboarding) : le compteur,
  // Louane qui naît du cercle, son résumé. Remplace le couple loading + ready,
  // qui reste en place derrière le drapeau.
  static const onboardingComprehension = '/onboarding-comprehension';
  static const onboardingLoading = '/onboarding-loading';
  static const onboardingReady = '/onboarding-ready';
  // Connexion Apple Santé — proposée uniquement sur iOS, APRÈS la respiration.
  static const onboardingSante = '/onboarding-sante';
  static const onboardingBreath = '/onboarding-breath';
  static const onboardingTrust = '/onboarding-trust';
  static const paywall = '/paywall';
  // Ouverture avec montée glissée (séance premium / profil)
  static const paywallSlide = '/paywall?from=premium';

  /// Comme [paywallSlide], avec la surface d'origine (louane, categorie,
  /// profil, seance…) — la Vigie s'en sert pour savoir ce qui convertit.
  static String paywallDepuis(String src) => '/paywall?from=premium&src=$src';
  static const shell = '/shell';
  static const home = '/home';
  static const louane = '/louane';
  static const profile = '/profile';
  // Le programme 7 jours créé par Louane : l'écran de génération (le moment
  // « wow ») et l'écran du programme lui-même.
  static const parcoursCreation = '/parcours/creation';
  static const parcours = '/parcours';
  static const player = '/player/:sessionId';
  static const preparation = '/preparation/:sessionId';
  // Lancement d'une séance par Louane : l'animation « je te la lance ».
  static const lancement = '/lancement/:sessionId';
  static const category = '/category/:categoryId';

  static String playerPath(String sessionId) => '/player/$sessionId';
  static String preparationPath(String sessionId) => '/preparation/$sessionId';
  static String lancementPath(String sessionId) => '/lancement/$sessionId';
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
      path: AppRoutes.onboardingConnexion,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: OnboardingConnexionPage(
          preview: state.uri.queryParameters['preview'] == '1',
        ),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboardingComprehension,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingComprehensionPage(),
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
      path: AppRoutes.onboardingSante,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const OnboardingHealthPage(),
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

    // ── Lancement par Louane (fondu, animation, puis player) ──
    GoRoute(
      path: AppRoutes.lancement,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: LancementSeancePage(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
    ),

    // ── Parcours : génération (fondu, le moment « wow ») ──
    GoRoute(
      path: AppRoutes.parcoursCreation,
      pageBuilder: (context, state) => QuietoTransitions.fadePage(
        key: state.pageKey,
        child: const ParcoursCreationPage(),
      ),
    ),

    // ── Parcours : le programme ────────────────────────
    // Ouverture normale : monte du bas, retour en fondu. Juste après la
    // création (?creation=1) : fondu, et la page joue sa révélation (la
    // constellation se dessine puis monte se poser en haut).
    GoRoute(
      path: AppRoutes.parcours,
      pageBuilder: (context, state) {
        final depuisCreation = state.uri.queryParameters['creation'] == '1';
        final page = ParcoursPage(depuisCreation: depuisCreation);
        return depuisCreation
            ? QuietoTransitions.fadePage(key: state.pageKey, child: page)
            : QuietoTransitions.sheetPage(
                key: state.pageKey, fadeBack: true, child: page);
      },
    ),

    // ── Player (moment immersif, monte du bas) ────────
    // Depuis le lancement Louane (?via=lancement) : fondu, dans la
    // continuité de l'animation — le Hero fait glisser le cover à sa place.
    GoRoute(
      path: AppRoutes.player,
      pageBuilder: (context, state) {
        final viaLancement = state.uri.queryParameters['via'] == 'lancement';
        final page = PlayerPage(
          sessionId: state.pathParameters['sessionId']!,
          viaLancement: viaLancement,
        );
        return viaLancement
            ? QuietoTransitions.fadePage(key: state.pageKey, child: page)
            : QuietoTransitions.sheetPage(key: state.pageKey, child: page);
      },
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
