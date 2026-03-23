import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/storage_providers.dart';

// ── Données fixes des particules (calculées au design-time) ───────────────
const List<_ParticleData> _kParticles = [
  _ParticleData(x: 0.12, baseY: 0.75, phase: 0.00, travel: 0.30),
  _ParticleData(x: 0.25, baseY: 0.85, phase: 0.30, travel: 0.25),
  _ParticleData(x: 0.45, baseY: 0.90, phase: 0.60, travel: 0.35),
  _ParticleData(x: 0.65, baseY: 0.80, phase: 0.10, travel: 0.28),
  _ParticleData(x: 0.82, baseY: 0.70, phase: 0.50, travel: 0.32),
  _ParticleData(x: 0.10, baseY: 0.60, phase: 0.80, travel: 0.20),
  _ParticleData(x: 0.55, baseY: 0.95, phase: 0.40, travel: 0.40),
  _ParticleData(x: 0.88, baseY: 0.88, phase: 0.70, travel: 0.22),
];

class _ParticleData {
  final double x;      // position horizontale (fraction de la largeur)
  final double baseY;  // position Y de départ (fraction de la hauteur)
  final double phase;  // décalage de phase 0.0–1.0
  final double travel; // distance parcourue (fraction de la hauteur)
  const _ParticleData({
    required this.x,
    required this.baseY,
    required this.phase,
    required this.travel,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class OnboardingLoadingPage extends ConsumerStatefulWidget {
  const OnboardingLoadingPage({super.key});

  @override
  ConsumerState<OnboardingLoadingPage> createState() =>
      _OnboardingLoadingPageState();
}

class _OnboardingLoadingPageState extends ConsumerState<OnboardingLoadingPage>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _waveController;
  late final AnimationController _particleController;
  late final Animation<double> _progressAnim;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // ── Progression 0 → 100% en 3000ms ───────────────────────────
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    );
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _navigated = true;
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) context.go(AppRoutes.onboardingPreview);
        });
      }
    });
    _progressController.forward();

    // ── Vagues en boucle (2000ms/cycle) ──────────────────────────
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // ── Particules en boucle (3000ms/cycle) ──────────────────────
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _waveController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = ref.watch(firstNameProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Particules flottantes (arrière-plan plein écran) ────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(
                  phase: _particleController.value,
                ),
              ),
            ),
          ),

          // ── Contenu principal ────────────────────────────────────
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset('assets/images/logo.png', width: 80, height: 80),
                  const SizedBox(height: 48),

                  // Vagues + cercle de progression
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vagues concentriques
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) => CustomPaint(
                            size: const Size(220, 220),
                            painter: _WavePainter(
                              wavePhase: _waveController.value,
                            ),
                          ),
                        ),
                        // Cercle de progression
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, _) => SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: _progressAnim.value,
                              color: AppColors.accent,
                              backgroundColor: AppColors.cardSurface,
                              strokeWidth: 8,
                            ),
                          ),
                        ),
                        // Pourcentage
                        AnimatedBuilder(
                          animation: _progressAnim,
                          builder: (context, _) {
                            final percent =
                                (_progressAnim.value * 100).round();
                            return Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w300,
                                color: AppColors.textPrimary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppConstants.spacingXl),

                  // Message personnalisé
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingXl,
                    ),
                    child: Text(
                      'Tes séances personnalisées arrivent'
                      '${firstName.isEmpty ? '' : ' $firstName'}...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painter : vagues concentriques ───────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double wavePhase; // 0.0 → 1.0, avance chaque frame

  const _WavePainter({required this.wavePhase});

  // Décalages de phase : 0ms / 400ms / 800ms sur cycle 2000ms
  static const double _offset2 = 400 / 2000;
  static const double _offset3 = 800 / 2000;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Vague 3 (extérieure, opacité la plus faible) — dessinée en premier
    _drawEllipse(canvas, center, wavePhase, 0.04, 105, 98);
    // Vague 2 (milieu)
    _drawEllipse(
        canvas, center, (wavePhase + _offset2) % 1.0, 0.06, 90, 84);
    // Vague 1 (intérieure, opacité la plus forte)
    _drawEllipse(
        canvas, center, (wavePhase + _offset3) % 1.0, 0.08, 75, 70);
  }

  void _drawEllipse(Canvas canvas, Offset center, double phase,
      double opacity, double baseRx, double baseRy) {
    // Oscillation douce via sin → scale dans [0.95, 1.05]
    final scale = 1.0 + 0.05 * math.sin(2 * math.pi * phase);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: baseRx * 2 * scale,
        height: baseRy * 2 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.wavePhase != wavePhase;
}

// ── Painter : particules flottantes ──────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double phase; // 0.0 → 1.0, avance chaque frame

  const _ParticlePainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _kParticles) {
      final t = (phase + p.phase) % 1.0;
      final opacity = 0.45 * (1.0 - t); // s'estompe en montant
      if (opacity <= 0) continue;

      final x = p.x * size.width;
      final y = (p.baseY - t * p.travel) * size.height;

      paint.color = AppColors.accent.withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), 4.0, paint); // 8px diamètre
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.phase != phase;
}
