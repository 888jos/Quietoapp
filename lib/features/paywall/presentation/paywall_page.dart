import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
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
  bool _showClose = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _closeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showClose = true);
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void _dismiss() => context.go(AppRoutes.home);

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
                  .copyWith(color: AppColors.textPrimary),
            ),
            backgroundColor: AppColors.cardSurface,
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
              Align(
                alignment: Alignment.centerRight,
                child: AnimatedOpacity(
                  opacity: _showClose ? 1.0 : 0.0,
                  duration: const Duration(
                      milliseconds: AppConstants.animNormal),
                  child: IgnorePointer(
                    ignoring: !_showClose,
                    child: IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                        size: 26,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              const Text('✨', style: TextStyle(fontSize: 88)),
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
                          color: AppColors.accent, size: 20),
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
