import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../paywall/paywall_providers.dart';
import '../data/weekly_program.dart';
import 'widgets/slide_reveal.dart';
import '../../../core/ui/starry_background.dart';

/// « {Prénom}, voici ton programme » : profil reformulé à partir des
/// réponses (pas de copier-coller du quiz) + programme de 7 jours
/// personnalisé, chaque jour cliquable avec le pourquoi de la séance.
class OnboardingReadyPage extends ConsumerStatefulWidget {
  const OnboardingReadyPage({super.key});

  @override
  ConsumerState<OnboardingReadyPage> createState() =>
      _OnboardingReadyPageState();
}

/// Nom du programme, dérivé de l'objectif n°1 : la promesse devient concrète
/// (« 7 jours pour… ») au lieu d'un objectif brut.
const _programNames = <String, String>{
  'Apaiser mon stress': '7 jours pour apaiser ton stress',
  'Mieux dormir': '7 jours pour mieux dormir',
  'Calmer mon anxiété': '7 jours pour calmer ton anxiété',
  'Me reconcentrer': '7 jours pour retrouver ta concentration',
  'Prendre soin de moi': '7 jours pour prendre soin de toi',
};

class _OnboardingReadyPageState extends ConsumerState<OnboardingReadyPage> {
  int _selectedDay = 0;

  @override
  void initState() {
    super.initState();
    ref.read(vigieProvider).log('onboarding_etape', {'etape': 'ready'});
    // Précharge l'Offering RevenueCat : le paywall (3 écrans plus loin)
    // s'ouvrira avec ses prix déjà en mémoire.
    ref.read(offeringProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final a = ref.read(storageServiceProvider).getOnboardingAnswers();
    final firstName = ref.read(firstNameProvider).trim();
    final experienced = (a['q2'] ?? '').contains('pratique');
    final priority = a['q1'] ?? '';
    final goals = (a['goals'] ?? '')
        .split('|')
        .where((g) => g.isNotEmpty)
        .toList();
    final minutes = a['q_minutes'] ?? '';
    final moment = a['q4'] ?? '';

    final profile = buildProfileSummary(
      priority: priority,
      goals: goals,
      minutes: minutes,
      moment: moment,
      experienced: experienced,
    );
    final program = buildWeeklyProgram(
      priority: priority,
      goals: goals,
      minutes: minutes,
      moment: moment,
      experienced: experienced,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SlideReveal(
                              active: true,
                              child: Text(
                                firstName.isEmpty
                                    ? 'Voici ton programme'
                                    : '$firstName, voici ton programme',
                                style: AppTextStyles.titleLarge,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingSm),
                            SlideReveal(
                              active: true,
                              delay: const Duration(milliseconds: 100),
                              child: Text(
                                'Construit à partir de tes réponses.',
                                style: AppTextStyles.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingLg),
                            SlideReveal(
                              active: true,
                              delay: const Duration(milliseconds: 200),
                              child: _PlanCard(
                                label: 'Ton programme',
                                value:
                                    _programNames[priority] ??
                                    '7 jours pour retrouver le calme',
                                highlighted: true,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingMd),
                            SlideReveal(
                              active: true,
                              delay: const Duration(milliseconds: 320),
                              child: _PlanCard(
                                label: 'Ce qu\'on a compris',
                                value: profile,
                                valueIsBody: true,
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingLg),
                            SlideReveal(
                              active: true,
                              delay: const Duration(milliseconds: 440),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(7, (i) {
                                  return _DayChip(
                                    index: i,
                                    selected: i == _selectedDay,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _selectedDay = i);
                                    },
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: AppConstants.spacingMd),
                            SlideReveal(
                              active: true,
                              delay: const Duration(milliseconds: 560),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween(
                                          begin: const Offset(0, 0.04),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                child: _DayDetailCard(
                                  key: ValueKey(_selectedDay),
                                  index: _selectedDay,
                                  day: program[_selectedDay],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SlideReveal(
                    active: true,
                    delay: const Duration(milliseconds: 680),
                    child: AppButton(
                      label: 'Essayer maintenant (30 s)',
                      // Sur iPhone, on propose d'abord la connexion à Apple
                      // Santé ; ailleurs, direct vers la respiration.
                      onTap: () => context.go(Platform.isIOS
                          ? AppRoutes.onboardingSante
                          : AppRoutes.onboardingBreath),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 38,
        height: 48,
        margin: EdgeInsets.only(right: index < 6 ? 7 : 0),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentDim : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'J${index + 1}',
              style: TextStyle(
                color: selected ? AppColors.accent : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (index == 0)
              const Text(
                'Auj.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }
}

/// Détail du jour sélectionné : la séance du jour + pourquoi elle fait
/// du bien, en une phrase.
class _DayDetailCard extends StatelessWidget {
  final int index;
  final ProgramDay day;

  const _DayDetailCard({super.key, required this.index, required this.day});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index == 0 ? 'JOUR 1 · AUJOURD\'HUI' : 'JOUR ${index + 1}',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            day.title,
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(day.why, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String value;
  final bool highlighted;

  /// true pour un texte long (profil) : corps plus petit, non gras.
  final bool valueIsBody;

  const _PlanCard({
    required this.label,
    required this.value,
    this.highlighted = false,
    this.valueIsBody = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accentDim : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: highlighted
            ? Border.all(color: AppColors.accent, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: valueIsBody
                ? AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                  )
                : AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
