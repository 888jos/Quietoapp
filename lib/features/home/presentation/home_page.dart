import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/session_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/app_scaffold.dart';
import '../home_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
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
                    Text('Bonjour 🌿',
                        style: AppTextStyles.bodyMedium),
                    const SizedBox(height: AppConstants.spacingXs),
                    Text('Comment vous sentez-vous ?',
                        style: AppTextStyles.displayLarge),
                    const SizedBox(height: AppConstants.spacingXl),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd),
              sliver: SliverList.separated(
                separatorBuilder: (ctx, i2) =>
                    const SizedBox(height: AppConstants.spacingMd),
                itemCount: categories.length,
                itemBuilder: (context, i) =>
                    _CategoryCard(category: categories[i]),
              ),
            ),
            const SliverPadding(
              padding:
                  EdgeInsets.only(bottom: AppConstants.spacingXl),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryModel category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category.emoji,
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(width: AppConstants.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.name,
                        style: AppTextStyles.titleMedium),
                    Text(
                      '${category.sessions.length} séances · ${category.totalMinutes} min',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          ...category.sessions.map(
            (s) => _SessionRow(session: s),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionModel session;

  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          context.push(AppRoutes.playerPath(session.id)),
      borderRadius:
          BorderRadius.circular(AppConstants.radiusSm),
      splashColor: AppColors.sageDim,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.spacingSm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.sageDim,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusSm),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: AppColors.sage, size: 22),
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.title,
                      style: AppTextStyles.bodyLarge),
                  Text(session.durationLabel,
                      style: AppTextStyles.badge),
                ],
              ),
            ),
            if (session.isPremium)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingSm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.sageDim,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text('Premium',
                    style: AppTextStyles.badge),
              ),
          ],
        ),
      ),
    );
  }
}
