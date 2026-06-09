import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_scaffold.dart';
import '../onboarding_providers.dart';
import 'widgets/intro_slide.dart';
import 'widgets/progress_bar.dart';
import 'widgets/question_slide.dart';
import 'widgets/text_input_slide.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  final _firstNameFocus = FocusNode();
  int _page = 0;
  bool _loading = false;

  static const _totalSlides = 7;

  static const _q1Options = [
    'Un stress que je n\'arrive pas à lâcher',
    'Une tristesse ou un vide',
    'Des tensions avec les autres',
    'Un sentiment de flottement',
    'Rien de tout ça, tout roule',
  ];

  static const _q2Options = [
    'Depuis quelques heures',
    'Depuis quelques jours',
    'Depuis quelques semaines',
    'C\'est flou, ça dure depuis longtemps',
    'Aucun souci, je viens juste essayer',
  ];

  static const _q3Options = [
    'Mon sommeil',
    'Ma concentration',
    'Mes relations',
    'Mon énergie au quotidien',
    'Tout va, je veux juste prendre soin de moi',
  ];

  static const _q4Options = [
    'Le matin, pour bien démarrer',
    'Dans la journée, pour souffler',
    'Le soir, pour décompresser',
    'N\'importe quand, selon l\'humeur',
  ];

  bool get _isLastSlide => _page == _totalSlides - 1;

  bool _isSlideProceedable(OnboardingState state) {
    if (_page == 2) return state.answers.containsKey('q1');
    if (_page == 3) return state.answers.containsKey('q2');
    if (_page == 4) return state.answers.containsKey('q3');
    if (_page == 5) return state.answers.containsKey('q4');
    if (_page == 6) return state.firstName.trim().isNotEmpty;
    return true;
  }

  Future<void> _next() async {
    if (_isLastSlide) {
      await _finish();
    } else {
      await _controller.nextPage(
        duration:
            const Duration(milliseconds: AppConstants.animNormal),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      final state = ref.read(onboardingProvider);
      final storage = ref.read(storageServiceProvider);
      await storage.saveOnboardingAnswers(state.answers);
      await storage.setFirstName(state.firstName.trim());
      await storage.setOnboardingDone();
      if (!mounted) return;
      // Met à jour le firstNameProvider pour que loading/preview lisent le bon prénom
      ref.read(firstNameProvider.notifier).state = state.firstName.trim();
      context.go(AppRoutes.onboardingLoading);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstNameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final canProceed = _isSlideProceedable(state);

    return AppScaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg),
          child: Column(
            children: [
              const SizedBox(height: AppConstants.spacingSm),
              // Flèche retour discrète (cachée sur la première slide)
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    opacity: _page > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: _page == 0,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _controller.previousPage(
                            duration: const Duration(
                                milliseconds: AppConstants.animNormal),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              OnboardingProgressBar(
                  current: _page, total: _totalSlides),
              const SizedBox(height: AppConstants.spacingMd),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) {
                    setState(() => _page = i);
                    // Focus la slide prénom seulement après la fin de l'animation
                    // (évite que le clavier monte pendant le slide)
                    if (i == _totalSlides - 1) {
                      Future.delayed(
                        const Duration(
                            milliseconds: AppConstants.animNormal + 50),
                        () {
                          if (mounted) _firstNameFocus.requestFocus();
                        },
                      );
                    }
                  },
                  children: [
                    // Slide 0 — Intro 1
                    const IntroSlide(
                      emoji: '🌿',
                      title: 'Bienvenue dans Quieto',
                      subtitle:
                          'Un espace calme pour méditer,\nrespirer et vous recentrer.',
                    ),

                    // Slide 1 — Intro 2
                    const IntroSlide(
                      emoji: '🎧',
                      title: 'Des séances guidées',
                      subtitle:
                          'Des méditations en français\npour tous les niveaux.',
                    ),

                    // Slide 2 — Q1
                    QuestionSlide(
                      question:
                          'Qu\'est-ce qui t\'amène à méditer aujourd\'hui ?',
                      options: _q1Options,
                      selectedOption: state.answers['q1'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q1', v),
                    ),

                    // Slide 3 — Q2
                    QuestionSlide(
                      question: 'C\'est quelque chose que tu ressens... ?',
                      options: _q2Options,
                      selectedOption: state.answers['q2'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q2', v),
                    ),

                    // Slide 4 — Q3
                    QuestionSlide(
                      question: 'Qu\'est-ce que ça affecte le plus ?',
                      options: _q3Options,
                      selectedOption: state.answers['q3'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q3', v),
                    ),

                    // Slide 5 — Q4
                    QuestionSlide(
                      question:
                          'Tu aurais plutôt 5 minutes pour toi... ?',
                      options: _q4Options,
                      selectedOption: state.answers['q4'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q4', v),
                    ),

                    // Slide 6 — Prénom
                    TextInputSlide(
                      question: "Comment tu t'appelles ?",
                      hint: 'Ton prénom',
                      initialValue: state.firstName,
                      focusNode: _firstNameFocus,
                      onChanged: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setFirstName(v),
                      onSubmitted: canProceed ? _next : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              AppButton(
                label: _isLastSlide ? 'Commencer' : 'Suivant',
                onTap: canProceed ? _next : null,
                isLoading: _loading,
              ),
              const SizedBox(height: AppConstants.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}
