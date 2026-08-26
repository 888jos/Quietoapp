import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/starry_background.dart';
import '../home_providers.dart';
import '../../explore/explore_providers.dart';
import 'widgets/category_list_card.dart';
import 'widgets/featured_session_card.dart';
import 'widgets/night_sky_header.dart';
import 'widgets/parcours_card.dart';

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
    // Vigie : arrivée sur l'accueil = ligne d'arrivée du funnel d'entrée
    // (onboarding → paywall → home). Une fois par session (initState).
    ref.read(vigieProvider).log('home_vue');
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

  /// Salutation selon l'heure : matin, journée, soirée, nuit.
  static String _salutation(String name) {
    final h = DateTime.now().hour;
    final salut = switch (h) {
      >= 5 && < 12 => 'Bonjour',
      >= 12 && < 18 => 'Bel après-midi',
      >= 18 && < 23 => 'Bonsoir',
      _ => 'Douce nuit',
    };
    return name.isEmpty ? salut : '$salut $name';
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final firstName = ref.watch(userFirstNameProvider);
    final salut = _salutation(firstName);

    return AppScaffold(
      body: Stack(
        children: [
          // Ciel étoilé partagé avec l'onboarding et le paywall : la Home
          // respire la même nuit douce que le reste de l'app.
          const Positioned.fill(child: StarryBackground()),
          // L'aurore boréale, hors SafeArea : elle monte jusque derrière
          // la barre d'état et se dissout sans jamais être coupée.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: AuroraSky(),
          ),
          // Poussière d'étoiles : fixée au fond comme l'aurore (elle ne
          // défile pas). L'arc reste au pixel sur son ancienne place
          // (~166 sous la barre d'état) mais le canvas est haut : la lueur
          // laiteuse a la place de s'étirer et de fondre dans le bas de
          // l'aurore. Même fondu d'arrivée que le header pour que la scène
          // apparaisse d'un seul tenant.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 30,
            left: 0,
            right: 0,
            height: 170,
            child: FadeTransition(
              opacity: _fadeController,
              child: const StardustTrail(arcRatio: 0.8),
            ),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                // ── Header : ciel de nuit (lune, brume qui dérive,
                // salutation seule). Une scène, presque pas de texte.
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: NightSkyHeader(greeting: salut),
                  ),
                ),

                // ── Programme en cours (créé par Louane) ──────────
                // Invisible sans programme actif : la carte se rend vide.
                // Pas de padding vertical ici : l'espacement vit DANS la
                // carte (il disparaît avec elle). Elle se place juste sous
                // le header, bien détachée de « Priorité du moment ».
                const SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingMd,
                  ),
                  sliver: SliverToBoxAdapter(child: ParcoursCard()),
                ),

                // ── Priorité du moment ────────────────────────────
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
                          'Priorité du moment',
                          style: AppTextStyles.titleLarge,
                        ),
                        const SizedBox(height: AppConstants.spacingMd),
                        FeaturedSessionCard(
                          categoryId: 'decouverte',
                          categoryName: 'Découverte de la méditation',
                          durationLabel: '3 séances disponibles',
                          // Même visuel que le haut de la page catégorie :
                          // la carte annonce ce qu'on ouvre.
                          imageFile: 'categories/decouverte.jpg',
                          onTap: () {
                            // Vigie : où cliquent-ils depuis l'accueil ?
                            ref.read(vigieProvider).log('categorie_ouverte', {
                              'categorie': 'decouverte',
                              'source': 'priorite',
                            });
                            context.push(
                              ref.read(categoryRouteProvider('decouverte')),
                            );
                          },
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
                      onTap: () {
                        ref.read(vigieProvider).log('categorie_ouverte', {
                          'categorie': categories[i].id,
                          'source': 'liste',
                        });
                        context.push(
                          ref.read(categoryRouteProvider(categories[i].id)),
                        );
                      },
                    ),
                  ),
                ),

                const SliverPadding(
                  padding: EdgeInsets.only(bottom: AppConstants.spacingXl),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
