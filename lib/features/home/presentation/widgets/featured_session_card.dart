import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/app_button.dart';

class FeaturedSessionCard extends StatelessWidget {
  final String emoji;
  final String categoryName;
  final String subtitle;
  final String durationLabel;
  final VoidCallback onTap;

  const FeaturedSessionCard({
    super.key,
    required this.emoji,
    required this.categoryName,
    required this.subtitle,
    required this.durationLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: AppConstants.spacingXs),
          Text(categoryName, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(durationLabel, style: AppTextStyles.caption),
              AppButton(
                label: 'Commencer',
                onTap: onTap,
                fullWidth: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
