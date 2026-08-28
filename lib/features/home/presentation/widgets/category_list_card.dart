import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/new_badge.dart';

/// Carte catégorie de l'accueil : l'illustration gouache de la catégorie en
/// pleine carte (choix de Paul, 28/08 — les gouaches sont la signature
/// visuelle de l'app, elles doivent se voir dès l'accueil), titre et nombre
/// de séances posés sur un voile en bas. La description vit sur la page
/// détail.
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
    final cover = _cover;

    return Semantics(
      button: true,
      label: 'Catégorie ${category.name}, ${category.sessions.length} séances',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Le liseré clair passe en foregroundDecoration : dans decoration,
          // l'image posée par-dessus le recouvrirait.
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover != null)
                  Image.asset(
                    'assets/images/$cover',
                    fit: BoxFit.cover,
                    alignment: Alignment(0, category.coverAlignmentY),
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppColors.cardSurface),
                  )
                else
                  const ColoredBox(color: AppColors.cardSurface),
                // Voile pour asseoir le texte : teinte du fond (jamais de
                // noir transparent) et courbe en S — mêmes leçons que le
                // fondu de la page détail. Le haut de l'image reste net.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 0.52, 0.68, 0.84, 1.0],
                      colors: [
                        AppColors.background.withValues(alpha: 0.0),
                        AppColors.background.withValues(alpha: 0.12),
                        AppColors.background.withValues(alpha: 0.38),
                        AppColors.background.withValues(alpha: 0.68),
                        AppColors.background.withValues(alpha: 0.88),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: AppConstants.spacingMd,
                  right: AppConstants.spacingMd,
                  bottom: AppConstants.spacingSm + 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          category.name,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                if (category.badge != null)
                  Positioned(
                    top: AppConstants.spacingSm,
                    right: AppConstants.spacingSm,
                    child: NewBadge(label: category.badge!),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
