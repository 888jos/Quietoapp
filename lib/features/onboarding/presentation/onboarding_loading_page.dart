import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/starry_background.dart';

class _PhraseData {
  final String label;
  final double threshold; // seuil de progression (0.0–1.0) déclenchant le fade
  const _PhraseData({required this.label, required this.threshold});
}

/// « On prépare ton programme » : barre circulaire + phrases qui apparaissent
/// une par une (labor illusion, avec les vraies réponses de l'utilisateur).
/// Même ciel étoilé que le reste de l'onboarding.
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
  late final Animation<double> _progressAnim;
  final Set<int> _vibratedPhrases = {};
  bool _navigated = false;

  late final List<_PhraseData> _phrases;

  @override
  void initState() {
    super.initState();

    final a = ref.read(storageServiceProvider).getOnboardingAnswers();
    final name = ref.read(firstNameProvider).trim();
    // Tous les objectifs cochés sont cités (en version courte),
    // pas seulement le premier : la personne voit qu'on a tout retenu.
    const shortGoals = <String, String>{
      'Apaiser mon stress': 'stress',
      'Mieux dormir': 'sommeil',
      'Calmer mon anxiété': 'anxiété',
      'Me reconcentrer': 'concentration',
      'Prendre soin de moi': 'soin de toi',
    };
    final goals = (a['goals'] ?? '')
        .split('|')
        .where((g) => g.isNotEmpty)
        .toList();
    final goalLabel = goals.length > 1
        ? 'Objectifs : ${goals.map((g) => shortGoals[g] ?? g).join(' · ')}'
        : 'Objectif : ${a['q1'] ?? 'retrouver le calme'}';
    _phrases = [
      const _PhraseData(label: 'Analyse de tes réponses', threshold: 0.00),
      _PhraseData(label: goalLabel, threshold: 0.20),
      const _PhraseData(
          label: 'Sélection des séances adaptées', threshold: 0.40),
      _PhraseData(
          label:
              'Rythme : ${a['q_minutes'] ?? 'quelques minutes'} · ${(a['q4'] ?? 'le soir').split(',').first.toLowerCase()}',
          threshold: 0.60),
      _PhraseData(
          label: name.isNotEmpty
              ? 'Le programme de $name est prêt'
              : 'Ton programme est prêt',
          threshold: 0.80),
    ];

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
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) context.go(AppRoutes.onboardingReady);
        });
      }
    });
    _progressAnim.addListener(() {
      for (var i = 0; i < _phrases.length; i++) {
        if (_progressAnim.value >= _phrases[i].threshold &&
            !_vibratedPhrases.contains(i)) {
          _vibratedPhrases.add(i);
          HapticFeedback.lightImpact();
        }
      }
    });
    _progressController.forward();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  // Opacité d'une phrase : fade in sur 400ms dès que le seuil est atteint
  double _phraseOpacity(int index) {
    const fadeDuration = 0.08; // 400ms / 5000ms
    final t = (_progressAnim.value - _phrases[index].threshold) / fadeDuration;
    return t.clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Vagues + cercle de progression
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, _) => CustomPaint(
                            size: const Size(220, 220),
                            painter: _WavePainter(
                              wavePhase: _waveController.value,
                            ),
                          ),
                        ),
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

                  const SizedBox(height: AppConstants.spacingXxl),

                  // Phrases progressives (fade in une par une), puce turquoise
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingXl),
                    child: AnimatedBuilder(
                      animation: _progressAnim,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_phrases.length, (i) {
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: i < _phrases.length - 1 ? 14.0 : 0.0,
                            ),
                            child: Opacity(
                              opacity: _phraseOpacity(i),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accentDim,
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _phrases[i].label,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
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

  static const double _offset2 = 400 / 2000;
  static const double _offset3 = 800 / 2000;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _drawEllipse(canvas, center, wavePhase, 0.04, 105, 98);
    _drawEllipse(
        canvas, center, (wavePhase + _offset2) % 1.0, 0.06, 90, 84);
    _drawEllipse(
        canvas, center, (wavePhase + _offset3) % 1.0, 0.08, 75, 70);
  }

  void _drawEllipse(Canvas canvas, Offset center, double phase,
      double opacity, double baseRx, double baseRy) {
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
