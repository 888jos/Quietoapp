import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/category_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_scaffold.dart';
import '../explore_providers.dart';

class ExplorePage extends ConsumerWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(filteredCategoriesProvider);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingLg,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explorer', style: AppTextStyles.displayLarge),
                    const SizedBox(height: AppConstants.spacingLg),
                    _SearchField(),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd),
              sliver: SliverGrid.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppConstants.spacingMd,
                  mainAxisSpacing: AppConstants.spacingMd,
                  childAspectRatio: 1.1,
                ),
                itemCount: categories.length,
                itemBuilder: (context, i) => _CategoryGridCard(
                  category: categories[i],
                  onTap: () => context.go(
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

class _SearchField extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextField(
      onChanged: (v) =>
          ref.read(searchQueryProvider.notifier).state = v,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Rechercher une séance...',
        hintStyle: AppTextStyles.bodyMedium,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.cardSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingMd,
          horizontal: AppConstants.spacingMd,
        ),
      ),
    );
  }
}

class _CategoryGridCard extends StatelessWidget {
  final CategoryModel category;
  final VoidCallback onTap;

  const _CategoryGridCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderRadius: AppConstants.radiusLg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(category.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            category.name,
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            '${category.sessions.length} séances',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
