import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_scaffold.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _steps = [
    _OnboardingStep(
      emoji: '🌿',
      title: 'Bienvenue dans Quieto',
      subtitle: 'Un espace calme pour méditer,\nbrespirez et vous recentrer.',
    ),
    _OnboardingStep(
      emoji: '🎧',
      title: 'Des séances guidées',
      subtitle: 'Des méditations en français\npour tous les niveaux.',
    ),
    _OnboardingStep(
      emoji: '✨',
      title: 'À votre rythme',
      subtitle: 'Quelques minutes par jour\npour transformer votre quotidien.',
    ),
  ];

  bool get _isLast => _page == _steps.length - 1;

  void _next() {
    if (_isLast) {
      context.go(AppRoutes.home);
    } else {
      _controller.nextPage(
        duration:
            const Duration(milliseconds: AppConstants.animNormal),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemCount: _steps.length,
                  itemBuilder: (_, i) => _StepView(step: _steps[i]),
                ),
              ),
              // Indicateurs
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(
                        milliseconds: AppConstants.animFast),
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingXs),
                    width: i == _page ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.accent
                          : AppColors.accentDim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spacingXl),
              AppButton(
                label: _isLast ? 'Commencer' : 'Suivant',
                onTap: _next,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              if (!_isLast)
                GestureDetector(
                  onTap: () => context.go(AppRoutes.home),
                  child: Text(
                    'Passer',
                    style: AppTextStyles.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final String emoji;
  final String title;
  final String subtitle;

  const _OnboardingStep({
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class _StepView extends StatelessWidget {
  final _OnboardingStep step;

  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(step.emoji, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: AppConstants.spacingXl),
        Text(
          step.title,
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          step.subtitle,
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
