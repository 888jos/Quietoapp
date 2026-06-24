import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Slide récap — effet miroir : on rejoue à l'utilisateur ses propres réponses
/// juste avant la « création de son programme », pour qu'il se sente compris.
///
/// Style volontairement aligné sur le reste de l'onboarding
/// (IntroSlide / QuestionSlide) : centré, un emoji en tête, des cartes douces
/// arrondies, et une apparition en cascade. Aucune direction artistique
/// inventée — on reste dans le langage visuel de Quieto.
///
/// API publique inchangée : RecapSlide({firstName, answers}) avec q1/q3/q4.
class RecapSlide extends StatelessWidget {
  final String firstName;
  final Map<String, String> answers;

  const RecapSlide({
    super.key,
    required this.firstName,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    final q1 = answers['q1'];
    final q3 = answers['q3'];
    final q4 = answers['q4'];

    // Liste des réponses présentes (on saute proprement celles absentes/vides).
    final items = <_RecapItem>[
      if (q1 != null && q1.trim().isNotEmpty)
        _RecapItem(label: 'Ce qui t\'amène', value: q1.trim()),
      if (q3 != null && q3.trim().isNotEmpty)
        _RecapItem(label: 'Ce que tu veux apaiser', value: q3.trim()),
      if (q4 != null && q4.trim().isNotEmpty)
        _RecapItem(label: 'Ton moment', value: q4.trim()),
    ];

    final name = firstName.trim();

    // Cadencement doux de la cascade (en ms).
    const emojiDelay = 0;
    const titleDelay = 140;
    const firstCardDelay = 320;
    const cardStep = 160;
    final footerDelay = firstCardDelay + items.length * cardStep + 80;

    // Centré quand ça rentre, scrollable si l'écran est petit.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Emoji centré, comme les slides d'intro.
                  _Reveal(
                    delayMs: emojiDelay,
                    child: const Text(
                      '✨',
                      style: TextStyle(fontSize: 64),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingLg),

                  // Titre centré, avec le prénom en turquoise.
                  _Reveal(
                    delayMs: titleDelay,
                    child: _RecapTitle(name: name),
                  ),
                  const SizedBox(height: AppConstants.spacingXl),

                  // Les réponses, en cartes douces — même langage que les
                  // cartes de QuestionSlide.
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(
                          bottom: AppConstants.spacingMd),
                      child: _Reveal(
                        delayMs: firstCardDelay + i * cardStep,
                        child: _RecapCard(item: items[i]),
                      ),
                    ),

                  const SizedBox(height: AppConstants.spacingSm),

                  // Phrase de clôture, douce.
                  _Reveal(
                    delayMs: footerDelay,
                    child: Text(
                      'On compose un programme rien que pour toi.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Titre « Ce qu'on a compris de toi, [Prénom] » avec le prénom en turquoise.
class _RecapTitle extends StatelessWidget {
  final String name;

  const _RecapTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    final base = AppTextStyles.titleLarge;

    if (name.isEmpty) {
      return Text(
        'Ce qu\'on a compris de toi',
        style: base,
        textAlign: TextAlign.center,
      );
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Ce qu\'on a compris de toi, '),
          TextSpan(
            text: name,
            style: base.copyWith(color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

class _RecapItem {
  final String label;
  final String value;

  const _RecapItem({required this.label, required this.value});
}

/// Une réponse, présentée comme une carte douce (reprend exactement le style
/// des cartes d'options de QuestionSlide : fond cardSurface, coins arrondis,
/// fine bordure turquoise discrète).
class _RecapCard extends StatelessWidget {
  final _RecapItem item;

  const _RecapCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingMd,
        vertical: AppConstants.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            item.label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.accent,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            item.value,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Anime l'apparition d'un enfant : fondu doux + léger glissement vers le haut,
/// avec un délai pour l'effet cascade. Pur Flutter (TweenAnimationBuilder).
class _Reveal extends StatelessWidget {
  final Widget child;
  final int delayMs;

  const _Reveal({required this.child, required this.delayMs});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: AppConstants.animSlow + 200),
      curve: Interval(
        _clampDelay(delayMs),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  static double _clampDelay(int delayMs) {
    const span = (AppConstants.animSlow + 200) * 3;
    final ratio = delayMs / span;
    return ratio.clamp(0.0, 0.85);
  }
}
