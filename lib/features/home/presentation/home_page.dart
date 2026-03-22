import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../home_providers.dart';
import '../../explore/explore_providers.dart';
import 'widgets/category_list_card.dart';
import 'widgets/featured_session_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppConstants.animSlow),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final firstName = ref.watch(userFirstNameProvider);
    final salut = firstName.isEmpty ? 'Salut,' : 'Salut $firstName,';
    final screenWidth = MediaQuery.of(context).size.width;

    return AppScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header épinglé ────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _HomeHeaderDelegate(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: Container(
                    color: AppColors.background,
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingMd,
                      AppConstants.spacingLg,
                      AppConstants.spacingMd,
                      AppConstants.spacingMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Image.asset('assets/images/logo.png', height: 48),
                            const SizedBox(width: AppConstants.spacingMd),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w300,
                                    color: AppColors.textPrimary,
                                  ),
                                  children: [
                                    TextSpan(text: '$salut\n'),
                                    const TextSpan(
                                        text: 'on fait quoi aujourd\'hui ?'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: screenWidth * 0.9,
                          height: 1,
                          color: AppColors.textPrimary.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Priorité du moment ────────────────────────────
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
                      emoji: '🧘',
                      categoryName: 'Découverte de la méditation',
                      subtitle: 'Commence ton voyage vers la pleine conscience.',
                      durationLabel: '3 séances disponibles',
                      onTap: () => context.push(
                        ref.read(categoryRouteProvider('decouverte')),
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

// ── Delegate pour le header épinglé ───────────────────────────

class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  // logo 48 + richtext ~54 (max) + margin 12 + separator 1
  // + padding top spacingLg(24) + padding bottom spacingMd(16)
  static const double _height = 116.0;

  final Widget child;

  const _HomeHeaderDelegate({required this.child});

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(_HomeHeaderDelegate oldDelegate) => true;
}
