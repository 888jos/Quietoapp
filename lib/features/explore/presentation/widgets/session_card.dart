import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: const Border(
            left: BorderSide(color: AppColors.accent, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingMd,
          vertical: AppConstants.spacingMd,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingXs),
                  Row(
                    children: [
                      const Icon(
                        Iconsax.timer_1,
                        size: 13,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppConstants.spacingXs),
                      Text(
                        session.durationLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accent,
                          fontSize: 13,
                        ),
                      ),
                      if (session.isPremium) ...[
                        const SizedBox(width: AppConstants.spacingSm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingXs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accentDim,
                            borderRadius:
                                BorderRadius.circular(AppConstants.radiusSm),
                          ),
                          child: Text(
                            'Premium',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accent,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.play,
                color: AppColors.background,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
