import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/theme/app_colors.dart';

class CategoryBubble extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const CategoryBubble({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                if (category.isNew)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingXs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'New !',
                        style: TextStyle(
                          color: AppColors.background,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              category.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
