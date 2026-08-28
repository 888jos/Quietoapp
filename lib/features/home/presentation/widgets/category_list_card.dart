import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/category_glyph.dart';
import '../../../../core/ui/new_badge.dart';

class CategoryListCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const CategoryListCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  /// Même repli que la page détail : couverture dédiée de la catégorie,
  /// sinon l'image de sa première séance.
  String? get _cover =>
      category.coverImage ??
      (category.sessions.isNotEmpty
          ? category.sessions.first.imageFile
          : null);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Catégorie ${category.name}, ${category.sessions.length} séances',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            // Même relief que la carte « Priorité du moment » : liseré
            // clair + ombre portée, la carte se décolle du ciel étoilé.
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Row(
            children: [
              // Pastille : l'illustration gouache de la catégorie (celle du
              // bandeau de sa page détail) en fond, le glyphe par-dessus.
              // Un voile sombre entre les deux garde le glyphe lisible sur
              // les paysages clairs.
              SizedBox(
                width: 56,
                height: 56,
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_cover != null)
                        Image.asset(
                          'assets/images/$_cover',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.accentDim),
                        )
                      else
                        const ColoredBox(color: AppColors.accentDim),
                      ColoredBox(
                        color: Colors.black.withValues(alpha: 0.28),
                      ),
                      Center(
                        child: CategoryGlyph(
                          categoryId: category.id,
                          fallbackEmoji: category.emoji,
                          size: 32,
                        ),
                      ),
                    ],
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
                        if (category.badge != null) ...[
                          const SizedBox(width: 8),
                          Transform.translate(
                            offset: const Offset(70, -28),
                            child: Transform.scale(
                              scale: 1.125,
                              child: NewBadge(label: category.badge!),
                            ),
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
