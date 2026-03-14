import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/services/storage_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(storageServiceProvider).loadProgress();

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profil', style: AppTextStyles.displayLarge),
                    const SizedBox(height: AppConstants.spacingXl),

                    // Stats
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            value: '${progress.totalMinutes}',
                            label: 'minutes',
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingMd),
                        Expanded(
                          child: _StatCard(
                            value: '${progress.completedCount}',
                            label: 'séances',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spacingXl),

                    // Premium CTA
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('✨ Passer à Premium',
                              style: AppTextStyles.titleMedium),
                          const SizedBox(height: AppConstants.spacingSm),
                          Text(
                            'Accédez à toutes les séances sans limite.',
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppConstants.spacingMd),
                          AppButton(
                            label: 'Voir les offres',
                            onTap: () => context.push(AppRoutes.paywall),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.displayLarge
                  .copyWith(color: AppColors.sage)),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
