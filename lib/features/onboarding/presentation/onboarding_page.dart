import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_text_styles.dart';
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
  int _page = 0;
  bool _loading = false;

  static const _totalSlides = 6;

  static const _q1Options = [
    'Réduire mon stress',
    'Mieux dormir',
    'Me recentrer',
    'Développer la pleine conscience',
  ];

  static const _q2Options = [
    'Le matin',
    'Dans la journée',
    'Le soir',
    'Variable',
  ];

  static const _q3Options = [
    'Anxieux(se)',
    'Fatigué(e)',
    'Stressé(e)',
    'Bien, mais curieux(se)',
  ];

  bool get _isIntroSlide => _page < 2;
  bool get _isLastSlide => _page == _totalSlides - 1;

  bool _isSlideProceedable(OnboardingState state) {
    if (_page == 2) return state.answers.containsKey('q1');
    if (_page == 3) return state.answers.containsKey('q2');
    if (_page == 4) return state.answers.containsKey('q3');
    if (_page == 5) return state.firstName.trim().isNotEmpty;
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

  Future<void> _skip() async {
    try {
      await ref.read(storageServiceProvider).setOnboardingDone();
    } catch (_) {}
    if (!mounted) return;
    context.go(AppRoutes.home);
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
      context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
              const SizedBox(height: AppConstants.spacingMd),
              OnboardingProgressBar(
                  current: _page, total: _totalSlides),
              const SizedBox(height: AppConstants.spacingMd),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _page = i),
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
                      question: 'Quel est ton objectif principal ?',
                      options: _q1Options,
                      selectedOption: state.answers['q1'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q1', v),
                    ),

                    // Slide 3 — Q2
                    QuestionSlide(
                      question: 'Quand préfères-tu méditer ?',
                      options: _q2Options,
                      selectedOption: state.answers['q2'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q2', v),
                    ),

                    // Slide 4 — Q3
                    QuestionSlide(
                      question: 'Comment te sens-tu en ce moment ?',
                      options: _q3Options,
                      selectedOption: state.answers['q3'],
                      onSelect: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setAnswer('q3', v),
                    ),

                    // Slide 5 — Prénom
                    TextInputSlide(
                      question: "Comment tu t'appelles ?",
                      hint: 'Ton prénom',
                      initialValue: state.firstName,
                      onChanged: (v) => ref
                          .read(onboardingProvider.notifier)
                          .setFirstName(v),
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
              const SizedBox(height: AppConstants.spacingMd),
              SizedBox(
                height: AppConstants.spacingXl,
                child: _isIntroSlide
                    ? GestureDetector(
                        onTap: _skip,
                        child: Text(
                          'Passer',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppConstants.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}
