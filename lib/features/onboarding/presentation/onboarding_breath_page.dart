import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import 'widgets/breath_wave.dart';
import 'widgets/slide_reveal.dart';
import 'widgets/starry_background.dart';

/// Mini-respiration guidée de 30 s (3 × inspire 4 s / expire 6 s) : faire
/// RESSENTIR la valeur juste avant le paywall. Volontairement courte et
/// passable — une vraie séance ici ferait fuir (données Headspace : 38 %
/// d'abandon sur leur méditation d'onboarding).
class OnboardingBreathPage extends StatefulWidget {
  const OnboardingBreathPage({super.key});

  @override
  State<OnboardingBreathPage> createState() => _OnboardingBreathPageState();
}

class _OnboardingBreathPageState extends State<OnboardingBreathPage> {
  void _continue() => context.go(AppRoutes.onboardingTrust);

  @override
  Widget build(BuildContext context) {
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SlideReveal(
                          active: true,
                          child: Text(
                            'Respirons\nensemble',
                            style: AppTextStyles.displayLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingLg),
                        SlideReveal(
                          active: true,
                          delay: const Duration(milliseconds: 150),
                          child: const BreathWave(),
                        ),
                      ],
                    ),
                  ),
                  AppButton(label: 'Continuer', onTap: _continue),
                  const SizedBox(height: AppConstants.spacingSm),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _continue,
                    child: const Padding(
                      padding: EdgeInsets.all(AppConstants.spacingSm),
                      child: Text(
                        'Passer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
