import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart';
import '../../features/onboarding/onboarding_providers.dart';
import '../config/feature_flags.dart';
import '../services/storage_providers.dart';

/// Barre de navigation de l'onboarding, réservée au DEBUG.
///
/// Posée en haut à gauche par-dessus toute l'app (cf. `builder:` du
/// MaterialApp dans `app.dart`) :
///   ◀ ▶  sautent d'une étape d'onboarding à l'autre, les 5 questions du
///        quiz comprises (`/onboarding?q=N`) ;
///   ↻    repart de zéro (réponses, prénom et programme effacés) puis
///        renvoie sur l'écran de connexion.
///
/// Hors onboarding, seul ↻ reste : de quoi relancer le flux depuis
/// n'importe quel écran (home, Louane, profil…).
///
/// Éphémère : pleine opacité pendant 4 s après chaque geste ou changement
/// d'écran, puis elle s'efface à 20 % pour ne plus gêner la lecture — elle
/// reste cliquable et le moindre appui la ramène.
///
/// ⚠️ `kDebugMode` est une constante de compilation : en release, tout ce
/// qui suit est éliminé par le compilateur. Rien ne peut partir sur les
/// stores.
class DebugOnboardingBar extends ConsumerStatefulWidget {
  const DebugOnboardingBar({super.key});

  @override
  ConsumerState<DebugOnboardingBar> createState() => _DebugOnboardingBarState();
}

/// Une étape du parcours, à plat.
class _Etape {
  final String chemin;
  final String label;
  const _Etape(this.chemin, this.label);
}

/// L'onboarding dans l'ordre réel : connexion → quiz (5 questions) → fin de
/// questionnaire → santé (iOS) → respiration → confiance → paywall.
///
/// La fin du questionnaire dépend du drapeau [kAccueilLouaneOnboarding] :
/// l'écran fusionné (le compteur, puis Louane), ou l'ancien couple
/// « création » + « voici ton programme ».
final _etapes = <_Etape>[
  const _Etape(AppRoutes.onboardingConnexion, 'connexion'),
  const _Etape('${AppRoutes.onboarding}?q=0', '1 · prénom'),
  const _Etape('${AppRoutes.onboarding}?q=1', '2 · objectifs'),
  const _Etape('${AppRoutes.onboarding}?q=2', '3 · expérience'),
  const _Etape('${AppRoutes.onboarding}?q=3', '4 · moment'),
  const _Etape('${AppRoutes.onboarding}?q=4', '5 · durée'),
  if (kAccueilLouaneOnboarding)
    const _Etape(AppRoutes.onboardingComprehension, 'compréhension')
  else ...[
    const _Etape(AppRoutes.onboardingLoading, 'création'),
    const _Etape(AppRoutes.onboardingReady, 'prêt'),
  ],
  const _Etape(AppRoutes.onboardingSante, 'santé'),
  const _Etape(AppRoutes.onboardingBreath, 'respiration'),
  const _Etape(AppRoutes.onboardingTrust, 'confiance'),
  const _Etape(AppRoutes.paywall, 'paywall'),
];

/// Index de l'étape affichée, `null` si on est ailleurs dans l'app.
int? _indexCourant(Uri uri) {
  // Les 5 questions partagent la même route : c'est `?q=` qui les sépare.
  if (uri.path == AppRoutes.onboarding) {
    final q = int.tryParse(uri.queryParameters['q'] ?? '') ?? 0;
    return (1 + q).clamp(1, 5);
  }
  final i = _etapes.indexWhere((e) => e.chemin == uri.path);
  return i == -1 ? null : i;
}

class _DebugOnboardingBarState extends ConsumerState<DebugOnboardingBar> {
  Timer? _minuterie;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    appRouter.routerDelegate.addListener(_reveiller);
    _programmerEffacement();
  }

  @override
  void dispose() {
    appRouter.routerDelegate.removeListener(_reveiller);
    _minuterie?.cancel();
    super.dispose();
  }

  /// Le routeur peut notifier en plein build → on repousse d'une frame.
  void _reveiller() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveillerMaintenant());
  }

  void _reveillerMaintenant() {
    if (!mounted) return;
    if (!_visible) setState(() => _visible = true);
    _programmerEffacement();
  }

  void _programmerEffacement() {
    _minuterie?.cancel();
    _minuterie = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _aller(int index) {
    HapticFeedback.selectionClick();
    _reveillerMaintenant();
    appRouter.go(_etapes[index].chemin);
  }

  /// Efface tout ce que l'onboarding a écrit et repart de la connexion —
  /// pour revoir le parcours exactement comme un nouvel arrivant.
  Future<void> _rejouer() async {
    HapticFeedback.mediumImpact();
    _reveillerMaintenant();
    final storage = ref.read(storageServiceProvider);
    await storage.resetOnboarding();
    await storage.setFirstName('');
    await storage.clearParcours();
    if (!mounted) return;
    ref.read(firstNameProvider.notifier).state = '';
    ref.invalidate(onboardingProvider);
    appRouter.go(AppRoutes.onboardingConnexion);
  }

  Widget _bouton(IconData icone, VoidCallback? action) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: action,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Icon(
          icone,
          size: 16,
          color: action == null ? Colors.white24 : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Double sécurité : le `builder:` de l'app ne nous monte déjà qu'en debug.
    if (!kDebugMode) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: appRouter.routerDelegate,
      builder: (context, _) {
        final uri = appRouter.routerDelegate.currentConfiguration.uri;
        final index = _indexCourant(uri);

        return Align(
          alignment: Alignment.topLeft,
          child: Padding(
            // Sous la barre d'état : iOS ne transmet PAS les touches de
            // cette bande à l'app, un bouton posé dedans serait inerte.
            // Sur les écrans d'onboarding, la flèche retour occupe déjà le
            // coin → on se décale d'un cran vers le bas.
            padding: EdgeInsets.only(
              left: 6,
              top: MediaQuery.paddingOf(context).top +
                  (index == null ? 4 : 44),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0.2,
                duration: const Duration(milliseconds: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xE60F1B2A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index != null) ...[
                        _bouton(
                          Icons.chevron_left,
                          index > 0 ? () => _aller(index - 1) : null,
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 74),
                          child: Text(
                            _etapes[index].label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                        _bouton(
                          Icons.chevron_right,
                          index < _etapes.length - 1
                              ? () => _aller(index + 1)
                              : null,
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: Colors.white24,
                        ),
                      ],
                      _bouton(Icons.refresh, _rejouer),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
