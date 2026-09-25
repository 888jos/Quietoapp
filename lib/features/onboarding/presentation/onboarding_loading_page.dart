import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/starry_background.dart';
import '../../../core/ui/pouls_haptique.dart';
import 'widgets/cercle_comprehension.dart';

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

  /// Le pouls du compteur : de plus en plus rapproché et fort jusqu'à 100 %.
  final _pouls = PoulsHaptique();

  @override
  void initState() {
    super.initState();
    ref.read(vigieProvider).log('onboarding_etape', {'etape': 'loading'});

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
        // Arrivée à 100 % : le coup franc qui « pose » le compteur.
        PoulsHaptique.arrivee();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) context.go(AppRoutes.onboardingReady);
        });
      }
    });
    _progressAnim.addListener(() {
      // ── Le pouls du compteur ─────────────────────────────────────
      // Des impulsions de plus en plus rapprochées et de plus en plus
      // fortes à mesure que la barre monte (Paul, 12/09).
      _pouls.avancer(_progressAnim.value);
      // ── L'arrivée d'une phrase ────────────────────────────────────
      // Impact plus marqué que le cliquetis : on sent que quelque chose
      // vient de se poser, pas que le chiffre avance.
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
                    child: AnimatedBuilder(
                      animation:
                          Listenable.merge([_progressAnim, _waveController]),
                      builder: (context, _) => CercleComprehension(
                        phaseOndes: _waveController.value,
                        progression: _progressAnim.value,
                        centre: Text(
                          '${(_progressAnim.value * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
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
