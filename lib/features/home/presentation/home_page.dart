import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../home_providers.dart';
import '../../explore/explore_providers.dart';
import 'widgets/category_list_card.dart';
import 'widgets/express_card.dart';
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
    final expressSessions = ref.watch(expressSessionsProvider);
    final isPremium = ref.watch(subscriptionProvider);
    final firstName = ref.watch(userFirstNameProvider);
    final salut = firstName.isEmpty ? 'Salut,' : 'Salut $firstName,';
    final screenWidth = MediaQuery.of(context).size.width;

    return AppScaffold(
      body: CustomScrollView(
        slivers: [
          // ── Header épinglé ────────────────────────────────
          SliverAppBar(
            pinned: true,
            floating: false,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.background,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 116,
            centerTitle: false,
            titleSpacing: 0,
            title: FadeTransition(
              opacity: _fadeController,
              child: SizedBox(
                height: 116,
                child: Padding(
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
                          Image.asset(
                            'assets/images/Inside app.png',
                            height: 48,
                          ),
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
                                    text: 'on fait quoi aujourd\'hui ?',
                                  ),
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
                        color:
                            AppColors.textPrimary.withValues(alpha: 0.15),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Une minute pour toi (Express) ─────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingMd,
              AppConstants.spacingSm,
              0,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        right: AppConstants.spacingMd),
                    child: Row(
                      children: [
                        Text('Une minute pour toi',
                            style: AppTextStyles.titleLarge),
                        const SizedBox(width: AppConstants.spacingXs),
                        const Text('⚡', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: expressSessions.length,
                      padding: const EdgeInsets.only(
                          right: AppConstants.spacingMd),
                      separatorBuilder: (context, i) =>
                          const SizedBox(width: AppConstants.spacingMd),
                      itemBuilder: (context, i) {
                        final session = expressSessions[i];
                        return ExpressCard(
                          session: session,
                          onTap: () {
                            if (session.isPremium && !isPremium) {
                              context.push(AppRoutes.paywall);
                            } else {
                              context.push(
                                  AppRoutes.preparationPath(session.id));
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
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
                  Text('Priorité du moment',
                      style: AppTextStyles.titleLarge),
                  const SizedBox(height: AppConstants.spacingMd),
                  FeaturedSessionCard(
                    emoji: '🧘',
                    categoryName: 'Découverte de la méditation',
                    subtitle:
                        'Commence ton voyage vers la pleine conscience.',
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
    );
  }
}
