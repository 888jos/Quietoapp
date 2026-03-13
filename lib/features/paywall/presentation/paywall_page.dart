import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_scaffold.dart';

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});

  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  bool _isLoading = false;

  Future<void> _purchase() async {
    setState(() => _isLoading = true);
    try {
      // TODO: déclencher le flow RevenueCat
      await Future<void>.delayed(const Duration(seconds: 1));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Achat impossible. Réessayez.',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.parchment),
            ),
            backgroundColor: AppColors.cardForest,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            children: [
              const Spacer(),
              const Text('✨', style: TextStyle(fontSize: 72)),
              const SizedBox(height: AppConstants.spacingLg),
              Text(
                'Quieto Premium',
                style: AppTextStyles.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                'Accédez à toutes les séances guidées,\nsans limite ni publicité.',
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.spacingXxl),

              // Avantages
              ..._perks.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingMd),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.sage, size: 20),
                      const SizedBox(width: AppConstants.spacingMd),
                      Expanded(
                        child: Text(p, style: AppTextStyles.bodyLarge),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              AppButton(
                label: 'Commencer — 4,99 € / mois',
                onTap: _purchase,
                isLoading: _isLoading,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              AppButton(
                label: 'Restaurer mes achats',
                onTap: () {},
                variant: AppButtonVariant.ghost,
                fullWidth: false,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                'Annulez à tout moment. Sans engagement.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _perks = [
    'Toutes les séances guidées illimitées',
    'Nouvelles méditations chaque semaine',
    'Téléchargement hors-ligne',
    'Sans publicité',
  ];
}
