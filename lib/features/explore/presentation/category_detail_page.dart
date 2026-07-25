import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/category_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/category_glyph.dart';
import '../explore_providers.dart';
import 'widgets/session_card.dart';

class CategoryDetailPage extends ConsumerWidget {
  final String categoryId;

  const CategoryDetailPage({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = ref.watch(categoryByIdProvider(categoryId));

    if (category == null) {
      return AppScaffold(
        body: Center(
          child: Text(
            'Catégorie introuvable.',
            style: AppTextStyles.bodyMedium,
          ),
        ),
      );
    }

    final progress = ref.watch(categoryProgressProvider(categoryId));
    final percent = progress.total == 0
        ? 0.0
        : progress.completed / progress.total;

    return AppScaffold(
      // Pas de SafeArea : la couverture passe sous la barre de statut,
      // comme une page Notion. Le bouton retour, lui, s'en écarte.
      body: CustomScrollView(
        slivers: [
          // ── Header : couverture + pastille à cheval (style Notion) ──
          SliverToBoxAdapter(
            child: _CategoryHeader(category: category),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              AppConstants.spacingMd,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AppTextStyles.displayLarge,
                  ),
                  const SizedBox(height: AppConstants.spacingSm),

                  // Description
                  Text(
                    category.description,
                    style: AppTextStyles.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),

                  // Progress
                  Text(
                    '${progress.completed} / ${progress.total} séances · '
                    '${(percent * 100).round()}%',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppConstants.spacingXs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusSm,
                    ),
                    child: LinearProgressIndicator(
                      value: percent,
                      minHeight: 4,
                      backgroundColor: AppColors.accentDim,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
              ),
            ),
          ),

            // ── Session list ──────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
              ),
              sliver: SliverList.separated(
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppConstants.spacingMd),
                itemCount: category.sessions.length,
                itemBuilder: (context, i) {
                  final session = category.sessions[i];
                  return SessionCard(
                    session: session,
                    onTap: () {
                      // Verrou par séance : toute séance payante (marquée
                      // premium OU appartenant à une catégorie premium) renvoie
                      // au paywall si l'utilisateur n'est pas abonné. La
                      // catégorie, elle, reste librement parcourable.
                      if (ref.read(sessionLockedProvider(session))) {
                        context.push(AppRoutes.paywallDepuis('categorie'));
                      } else {
                        context.push(
                          AppRoutes.preparationPath(session.id),
                        );
                      }
                    },
                  );
                },
              ),
            ),

          // Le SafeArea a sauté (couverture bord à bord) : on rend ici la
          // marge du bas de l'écran (barre home iPhone) à la main.
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  AppConstants.spacingXl + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header : couverture pleine largeur + pastille à cheval ──
//
// Comme une page Notion : l'image passe sous la barre de statut, et la
// pastille (motif de la catégorie sur fond de page) est posée à cheval sur
// la frontière entre l'image et le contenu.

class _CategoryHeader extends StatelessWidget {
  final CategoryModel category;

  const _CategoryHeader({required this.category});

  /// Hauteur de l'image, barre de statut comprise.
  static const _coverBody = 180.0;

  /// Côté du motif de catégorie ; il déborde de moitié sous l'image.
  static const _badgeSize = 64.0;

  @override
  Widget build(BuildContext context) {
    final statusBar = MediaQuery.paddingOf(context).top;
    final coverHeight = statusBar + _coverBody;

    // Couverture dédiée si fournie, sinon l'image de la première séance.
    final cover = category.coverImage ??
        (category.sessions.isNotEmpty
            ? category.sessions.first.imageFile
            : null);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: coverHeight,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (cover != null)
                    Image.asset(
                      'assets/images/$cover',
                      fit: BoxFit.cover,
                      alignment: Alignment(0, category.coverAlignmentY),
                      errorBuilder: (_, _, _) => const _CoverFallback(),
                    )
                  else
                    const _CoverFallback(),
                  // Fondu vers le fond de page, pour que l'image se marie
                  // au thème sombre au lieu de se terminer net.
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.55, 1.0],
                        colors: [Colors.transparent, AppColors.background],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Espace où la moitié basse de la pastille déborde.
            const SizedBox(height: _badgeSize / 2 + AppConstants.spacingSm),
          ],
        ),

        // Bouton retour, par-dessus l'image, sous la barre de statut.
        Positioned(
          top: statusBar + AppConstants.spacingSm,
          left: AppConstants.spacingMd,
          child: Semantics(
            button: true,
            label: 'Retour',
            child: GestureDetector(
              onTap: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.home),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
              ),
            ),
          ),
        ),

        // Motif de la catégorie à cheval sur la frontière image / contenu,
        // sans cadre : son halo suffit à le détacher du fond.
        Positioned(
          top: coverHeight - _badgeSize / 2,
          left: AppConstants.spacingMd,
          child: CategoryGlyph(
            categoryId: category.id,
            fallbackEmoji: category.emoji,
            size: _badgeSize,
          ),
        ),
      ],
    );
  }
}

/// Couverture de secours tant que la catégorie n'a pas d'image : un dégradé
/// dans la direction artistique de l'app, jamais un trou noir.
class _CoverFallback extends StatelessWidget {
  const _CoverFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentDim, AppColors.background],
        ),
      ),
    );
  }
}
