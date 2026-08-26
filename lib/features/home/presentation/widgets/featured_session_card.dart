import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/category_glyph.dart';
import '../../../../core/ui/new_badge.dart';

class FeaturedSessionCard extends StatelessWidget {
  /// Identifiant de catégorie : affiche le motif Quieto dessiné en code
  /// (CategoryGlyph) en haut à gauche de la carte.
  final String? categoryId;
  final String categoryName;
  final String durationLabel;
  final VoidCallback onTap;
  final bool isNew;

  /// Chemin (relatif à assets/images/) de la vignette illustrée affichée à
  /// droite de la carte, texte à gauche — comme les cartes Headspace.
  final String? imageFile;

  const FeaturedSessionCard({
    super.key,
    this.categoryId,
    required this.categoryName,
    required this.durationLabel,
    required this.onTap,
    this.isNew = false,
    this.imageFile,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Priorité du moment : $categoryName, $durationLabel',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusLg + 1),
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
              child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: const Border(
                  left: BorderSide(color: AppColors.accent, width: 4),
                ),
              ),
              // Structure façon Headspace : titre + durée à gauche,
              // vignette arrondie à droite avec sa marge, centrés.
              padding: const EdgeInsets.all(AppConstants.spacingMd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (categoryId != null) ...[
                          CategoryGlyph(
                            categoryId: categoryId!,
                            fallbackEmoji: '🧘',
                            size: 36,
                          ),
                          const SizedBox(height: AppConstants.spacingXs),
                        ],
                        Text(categoryName, style: AppTextStyles.titleMedium),
                        const SizedBox(height: AppConstants.spacingSm),
                        Text(durationLabel, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  if (imageFile != null) ...[
                    const SizedBox(width: AppConstants.spacingMd),
                    // Ombre portée : la vignette se détache du fond
                    // de la carte (sans liseré).
                    Container(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        child: Image.asset(
                          'assets/images/$imageFile',
                          width: 148,
                          height: 96,
                          fit: BoxFit.cover,
                          // Image manquante : la carte redevient tout-texte
                          // au lieu d'afficher une brique d'erreur.
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              ),
            ),
            if (isNew)
              const Positioned(
                top: -8,
                right: AppConstants.spacingSm,
                child: NewBadge(),
              ),
          ],
        ),
      ),
    );
  }
}
