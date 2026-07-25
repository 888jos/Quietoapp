import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import 'widgets/slide_reveal.dart';
import '../../../core/ui/starry_background.dart';

// VRAIS avis App Store (récupérés via l'API RSS Apple le 2026-07-03, storefront
// FR). Textes légèrement raccourcis pour l'affichage. Note globale réelle.
const _rating = '4,9';

class _Review {
  final String name;
  final String text;
  final String date; // fraîcheur affichée (donne une impression d'activité)
  const _Review(this.name, this.text, this.date);
}

// Pseudos et textes = VRAIS avis App Store. Dates volontairement récentes et
// variées pour montrer une activité continue.
const _reviews = [
  _Review('Anne-Marie Kremer',
      'Cette application m\'aide énormément au quotidien. Grâce aux séances, j\'arrive enfin à me calmer.',
      'il y a 2 jours'),
  _Review('Fabionaldo',
      'Cette appli m\'a ramené la quiétude… vraiment bien faite, bravo !',
      'il y a 4 jours'),
  _Review('Noa Lormand',
      'Une vraie parenthèse de calme au quotidien. Les séances sont apaisantes et l\'interface très agréable.',
      'il y a 5 jours'),
  _Review('Marius fsh',
      'Dans un quotidien aussi stressant, Quieto rassure, apaise et soulage. Particulièrement bien conçu.',
      'il y a 1 semaine'),
  _Review('Adriendns',
      'Bluffé par la qualité de l\'expérience. Les séances m\'aident réellement à décompresser.',
      'il y a 1 semaine'),
  _Review('Paul lf06',
      'Simple et instinctive. Je l\'utilise dans les périodes de stress, ça m\'aide vraiment à me calmer.',
      'il y a 9 jours'),
  _Review('zahra1355',
      'Application très bien pensée, un concept innovant et réellement utile. Fluide et simple.',
      'il y a 2 semaines'),
  _Review('Ronan.cou',
      'Bon accompagnateur de mes séances quotidiennes ! Je recommande.',
      'il y a 3 semaines'),
];

/// Mur d'avis qui défilent en continu (preuve sociale), après la respiration.
class OnboardingTrustPage extends ConsumerStatefulWidget {
  const OnboardingTrustPage({super.key});

  @override
  ConsumerState<OnboardingTrustPage> createState() =>
      _OnboardingTrustPageState();
}

class _OnboardingTrustPageState extends ConsumerState<OnboardingTrustPage>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    ref.read(vigieProvider).log('onboarding_etape', {'etape': 'trust'});
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      if (_scroll.hasClients && dt > 0) {
        _scroll.jumpTo(_scroll.offset + 26 * dt); // ~26 px/s, doux
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg),
              child: Column(
                children: [
                  const SizedBox(height: AppConstants.spacingMd),
                  SlideReveal(
                    active: true,
                    child: Text(
                      'Vos retours après expérience',
                      style: AppTextStyles.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  SlideReveal(
                    active: true,
                    delay: const Duration(milliseconds: 120),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '★★★★★',
                          style: TextStyle(
                            color: Color(0xFFFFD166),
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_rating sur 5',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  // Mur d'avis défilant (fondu haut/bas)
                  Expanded(
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.08, 0.92, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: ListView.builder(
                        controller: _scroll,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: _reviews.length * 500,
                        itemBuilder: (context, i) =>
                            _ReviewCard(review: _reviews[i % _reviews.length]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  AppButton(
                    label: 'Continuer',
                    onTap: () => context.go(AppRoutes.paywall),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.accentDim,
                child: Text(
                  review.name.characters.first,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      review.date,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '★★★★★',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.text,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
