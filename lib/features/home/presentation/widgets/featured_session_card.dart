import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class FeaturedSessionCard extends StatelessWidget {
  final SessionModel session;
  final String categoryName;
  final VoidCallback onTap;

  const FeaturedSessionCard({
    super.key,
    required this.session,
    required this.categoryName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Text(
              categoryName,
              style: AppTextStyles.badge,
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              session.title,
              style: AppTextStyles.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  color: AppColors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: AppConstants.spacingXs),
                Text(
                  session.durationLabel,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
