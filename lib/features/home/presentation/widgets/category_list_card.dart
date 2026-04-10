import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/new_badge.dart';

class CategoryListCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const CategoryListCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Catégorie ${category.name}, ${category.sessions.length} séances',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.accentDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.name,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (category.isNew) ...[
                        const SizedBox(width: 8),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: const NewBadge(),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Text(
              '${category.sessions.length} séances',
              style: AppTextStyles.badge,
            ),
            const SizedBox(width: AppConstants.spacingXs),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.accent,
              size: 20,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
