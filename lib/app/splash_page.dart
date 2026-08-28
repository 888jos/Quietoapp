import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/services/storage_providers.dart';
import '../core/theme/app_colors.dart';
import 'router.dart';

/// Splash d'ouverture cinématique et doux : les éléments apparaissent
/// en cascade (logo → ondes → particules), puis tout vit en boucle calme.
/// Durée totale ~4500ms.
///
/// Phases :
///  - 0 → 1000ms : fade-in lent du logo (opacité + scale)
///  - 700 → 1700ms : apparition progressive des ondes
///  - 1200 → 2200ms : apparition progressive des particules
///  - 2200ms+ : tout tourne en boucle, logo commence à respirer
///  - 4500ms : redirection vers /onboarding ou /home
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  // Master controller de l'entrée (0 → 1 sur 3000ms) — pilote les fade-in
  // progressifs des 3 couches (logo, ondes, particules).
  late final AnimationController _entryController;

  // Animations en boucle (démarrent dès le début, mais leur opacité est
  // gérée par _entryController, donc elles montent progressivement).
  late final AnimationController _waveController;
  late final AnimationController _particleController;
  late final AnimationController _pulseController;

  // Fade-out final (0 → 1 sur 700ms) — fait disparaître tout le contenu
  // en douceur avant de naviguer vers /onboarding ou /home.
  late final AnimationController _exitController;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Entrée progressive (0 → 1 sur 3000ms — plus lent pour plus de douceur).
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..forward();

    // Ondes : cycle 4000ms (très lent, méditatif).
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Particules : cycle 5000ms (montée très lente).
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat();

    // Pulse du logo : démarre après l'entrée (délai 3000ms).
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) _pulseController.repeat(reverse: true);
    });

    // Fade-out final : démarre à 4800ms, dure 700ms.
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    Future.delayed(const Duration(milliseconds: 4800), () {
      if (mounted) _exitController.forward();
    });

    // Redirection à 5500ms (4800ms + 700ms de fade-out) — au moment où
    // le contenu est déjà totalement invisible, donc transition imperceptible.
    Future.delayed(const Duration(milliseconds: 5500), _redirect);
  }

  Future<void> _redirect() async {
    if (_navigated || !mounted) return;
    _navigated = true;
    final done = ref.read(storageServiceProvider).isOnboardingDone;
    if (!done) {
      context.go(AppRoutes.onboardingConnexion);
      return;
    }
    context.go(AppRoutes.home);
    // Mur d'ouverture (décision Paul, 28/08) : à chaque démarrage à FROID,
    // un non-abonné (ni premium ni essai en cours — l'entitlement RevenueCat
    // couvre les deux) repasse devant le paywall, fermable, avant la home.
    // Poussé par-dessus la home : la croix la révèle sans re-navigation.
    // Un simple retour du background ne repasse pas par le splash → rien.
    if (!ref.read(subscriptionProvider)) {
      context.push('${AppRoutes.paywall}?src=ouverture');
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  /// Calcule un fade-in progressif (0 → 1) sur un sous-intervalle de l'entrée.
  /// `start` et `end` sont des fractions de l'entrée (0.0 à 1.0).
  /// Curves.easeInOut pour une douceur naturelle.
  double _fadeIn(double start, double end) {
    final t = ((_entryController.value - start) / (end - start)).clamp(0.0, 1.0);
    return Curves.easeInOut.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AnimatedBuilder(
        // On écoute aussi _exitController pour rebuilder pendant le fade-out final.
        animation: Listenable.merge([_entryController, _exitController]),
        builder: (context, _) {
          // Opacité globale : 1.0 normalement, descend à 0.0 pendant la phase
          // de fade-out (entre 4800 et 5500ms). Le fond bleu nuit reste, seul
          // le contenu (logo, ondes, particules) disparaît en douceur.
          final exitOpacity = (1.0 - _exitController.value).clamp(0.0, 1.0);
          // Sous-intervalles d'apparition (en fractions de 3000ms) :
          //  - Logo  : 0 → 1800ms = 0.00 → 0.60 (lent et doux)
          //  - Ondes : 1500 → 2700ms = 0.50 → 0.90 (subtiles, après le logo)
          //  - Parts : 2000 → 3000ms = 0.67 → 1.00
          // Opacités d'apparition × opacité globale de sortie : quand
          // _exitController atteint 1.0, tout devient invisible en douceur.
          final logoOpacity = _fadeIn(0.0, 0.60) * exitOpacity;
          final waveOpacity = _fadeIn(0.50, 0.90) * exitOpacity;
          final particleOpacity = _fadeIn(0.67, 1.0) * exitOpacity;
          // Scale du logo : passe de 0.7 à 1.0 sur la phase d'entrée.
          final logoBaseScale = 0.7 + 0.3 * _fadeIn(0.0, 0.60);

          return Stack(
            children: [
              // Particules en arrière-plan (plein écran).
              Positioned.fill(
                child: Opacity(
                  opacity: particleOpacity,
                  child: AnimatedBuilder(
                    animation: _particleController,
                    builder: (context, _) => CustomPaint(
                      painter: _SplashParticlePainter(
                          phase: _particleController.value),
                    ),
                  ),
                ),
              ),
              // Centre : ondes pleines + logo qui respire.
              Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Vagues turquoise pleines qui se diffusent.
                      Opacity(
                        opacity: waveOpacity,
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) => CustomPaint(
                            size: const Size(360, 360),
                            painter: _SplashWavePainter(
                                phase: _waveController.value),
                          ),
                        ),
                      ),
                      // Logo rond avec fade-in + pulse en boucle (après entrée).
                      Opacity(
                        opacity: logoOpacity,
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse = 1.0 + 0.05 * _pulseController.value;
                            return Transform.scale(
                              scale: logoBaseScale * pulse,
                              child: child,
                            );
                          },
                          child: Image.asset(
                            'assets/images/logo rond.png',
                            width: 120,
                            height: 120,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 3 ondes pleines turquoise qui se diffusent en cercles concentriques.
class _SplashWavePainter extends CustomPainter {
  final double phase;
  const _SplashWavePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final t = (phase + i / 3) % 1.0;
      final radius = 70.0 + 100.0 * t;
      // Opacité plus subtile (0.12 max au lieu de 0.20) pour plus de douceur.
      final opacity = (1.0 - t) * 0.12;
      if (opacity <= 0) continue;
      final paint = Paint()
        ..color = AppColors.accent.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_SplashWavePainter old) => old.phase != phase;

  @override
  bool hitTest(Offset position) => false;
}

/// Particules turquoise qui flottent vers le haut en arrière-plan.
class _SplashParticlePainter extends CustomPainter {
  final double phase;
  const _SplashParticlePainter({required this.phase});

  static const List<List<double>> _particles = [
    [0.08, 0.95, 0.00],
    [0.18, 0.85, 0.30],
    [0.30, 0.92, 0.60],
    [0.42, 0.80, 0.10],
    [0.55, 0.95, 0.45],
    [0.65, 0.78, 0.75],
    [0.75, 0.90, 0.20],
    [0.85, 0.82, 0.55],
    [0.92, 0.95, 0.85],
    [0.50, 0.88, 0.70],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in _particles) {
      final t = (phase + p[2]) % 1.0;
      final opacity = 0.4 * (1.0 - t);
      if (opacity <= 0) continue;
      final x = p[0] * size.width;
      final y = (p[1] - t * 0.35) * size.height;
      paint.color = AppColors.accent.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(_SplashParticlePainter old) => old.phase != phase;

  @override
  bool hitTest(Offset position) => false;
}
