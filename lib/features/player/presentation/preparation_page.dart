import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../player_providers.dart';

class PreparationPage extends ConsumerStatefulWidget {
  final String sessionId;

  const PreparationPage({super.key, required this.sessionId});

  @override
  ConsumerState<PreparationPage> createState() => _PreparationPageState();
}

class _PreparationPageState extends ConsumerState<PreparationPage>
    with TickerProviderStateMixin {
  late final AnimationController _progressController;
  late final AnimationController _fadeController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );

    _progressController.forward();
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _startFadeAndNavigate();
      }
    });
  }

  Future<void> _startFadeAndNavigate() async {
    if (_navigated) return;
    _navigated = true;
    try {
      await _fadeController.reverse();
      if (!mounted) return;
      context.push(AppRoutes.playerPath(widget.sessionId));
    } catch (_) {}
  }

  @override
  void dispose() {
    _progressController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider(widget.sessionId));

    return GestureDetector(
      onTap: _startFadeAndNavigate,
      child: FadeTransition(
        opacity: _fadeController,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingLg),
              child: Column(
                children: [
                  const SizedBox(height: AppConstants.spacingXl),

                  // Titre de la séance
                  Text(
                    session?.title ?? '',
                    style: AppTextStyles.titleLarge,
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // Icône lotus
                  const Icon(
                    Icons.self_improvement,
                    size: 80,
                    color: AppColors.accent,
                  ),

                  const SizedBox(height: AppConstants.spacingXl),

                  // Messages
                  Text(
                    'Installez-vous tranquillement',
                    style: AppTextStyles.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'Touchez l\'écran quand vous êtes prêts',
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  Text(
                    '... ou patientez :)',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // Barre de progression 5 secondes
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                        child: LinearProgressIndicator(
                          value: _progressController.value,
                          minHeight: 4,
                          backgroundColor: AppColors.cardSurface,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.accent,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppConstants.spacingLg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
