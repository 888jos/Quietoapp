import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
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
          child: Text('Catégorie introuvable.', style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final progress = ref.watch(categoryProgressProvider(categoryId));
    final percent = progress.total == 0
        ? 0.0
        : progress.completed / progress.total;

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                AppConstants.spacingMd,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingLg),

                    // Emoji + title
                    Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: AppConstants.spacingSm),
                    Text(category.name, style: AppTextStyles.displayLarge),
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
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusSm),
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
                    onTap: () => context.push(
                      AppRoutes.playerPath(session.id),
                    ),
                  );
                },
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
