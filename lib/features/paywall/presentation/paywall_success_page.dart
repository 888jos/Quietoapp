import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_button.dart';

class _UnlockedCategory {
  final String emoji;
  final String label;
  const _UnlockedCategory(this.emoji, this.label);
}

const List<_UnlockedCategory> _kUnlocked = [
  _UnlockedCategory('🌬️', 'Respiration'),
  _UnlockedCategory('😤', 'Stress & Anxiété'),
  _UnlockedCategory('🌙', 'Sommeil'),
  _UnlockedCategory('💛', 'Émotions'),
  _UnlockedCategory('📰', 'Actualité'),
];

class PaywallSuccessPage extends ConsumerStatefulWidget {
  const PaywallSuccessPage({super.key});

  @override
  ConsumerState<PaywallSuccessPage> createState() => _PaywallSuccessPageState();
}

class _PaywallSuccessPageState extends ConsumerState<PaywallSuccessPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    // Vibration "you did it" sensorielle à l'arrivée
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = ref.watch(firstNameProvider);
    final greeting =
        firstName.isEmpty ? 'Bienvenue' : 'Bienvenue, $firstName';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingXl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/Inside app.png',
                          width: 80,
                          height: 80,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          greeting,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ton espace calme\nest maintenant complet ✨',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: 200,
                          height: 1,
                          color:
                              AppColors.textPrimary.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 32),
                        ..._kUnlocked.map(
                          (cat) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  cat.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  cat.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppConstants.spacingMd),
                child: AppButton(
                  label: 'Commencer maintenant',
                  onTap: () => context.go(AppRoutes.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
