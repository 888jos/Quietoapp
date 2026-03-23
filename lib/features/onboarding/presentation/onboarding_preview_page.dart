import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/services/storage_providers.dart';
import '../../explore/explore_providers.dart';

class OnboardingPreviewPage extends ConsumerWidget {
  const OnboardingPreviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = ref.watch(firstNameProvider);
    final categories = ref.watch(exploreCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
              ),
              child: Text(
                'Tes séances sont prêtes'
                '${firstName.isEmpty ? '' : ' $firstName'} 🎉',
                style: AppTextStyles.titleLarge,
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppConstants.spacingSm),
                itemBuilder: (context, i) {
                  final cat = categories[i];
                  return Container(
                    padding: const EdgeInsets.all(AppConstants.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Text(
                          cat.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: AppConstants.spacingMd),
                        Text(cat.name, style: AppTextStyles.bodyLarge),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: AppButton(
                label: 'Accéder à mes séances',
                onTap: () => context.go(AppRoutes.paywall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
