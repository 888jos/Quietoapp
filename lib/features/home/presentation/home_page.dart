import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../home_providers.dart';
import '../../explore/explore_providers.dart';
import 'widgets/category_bubble.dart';
import 'widgets/category_list_card.dart';
import 'widgets/featured_session_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final firstName = ref.watch(userFirstNameProvider);

    final greeting =
        firstName.isEmpty ? 'Bonjour' : 'Bonjour, $firstName';

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    Text(greeting, style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ),

            // ── Catégories scroll horizontal ──────────────────
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
                    Text(
                      'Programmes disponibles',
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppConstants.spacingMd),
                        itemBuilder: (context, i) => CategoryBubble(
                          category: categories[i],
                          onTap: () => context.push(
                            ref.read(categoryRouteProvider(categories[i].id)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Priorité du moment ────────────────────────────────
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
                    Text('Priorité du moment', style: AppTextStyles.titleLarge),
                    const SizedBox(height: AppConstants.spacingMd),
                    FeaturedSessionCard(
                      emoji: '🌍',
                      categoryName: 'Actualité & Surcharge mentale',
                      subtitle: 'Le monde est bruyant. Quieto est ta pause.',
                      durationLabel: '8 séances disponibles',
                      onTap: () => context.push(
                        ref.read(categoryRouteProvider('actualite')),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Catégories disponibles ────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Catégories disponibles',
                  style: AppTextStyles.titleLarge,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                0,
              ),
              sliver: SliverList.separated(
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppConstants.spacingSm),
                itemCount: categories.length,
                itemBuilder: (context, i) => CategoryListCard(
                  category: categories[i],
                  onTap: () => context.push(
                    ref.read(categoryRouteProvider(categories[i].id)),
                  ),
                ),
              ),
            ),

            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppConstants.spacingXl),
            ),
          ],
        ),
      ),
    );
  }
}
