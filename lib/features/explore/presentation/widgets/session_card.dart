import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../app/router.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../player/player_providers.dart';

class SessionCard extends ConsumerWidget {
  final SessionModel session;

  /// Appelé pour LANCER la séance (navigation vers la préparation) quand elle
  /// n'est pas déjà en cours. Le verrou premium est géré par l'appelant.
  final VoidCallback onTap;

  const SessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cette séance est-elle celle en cours dans le lecteur ?
    final isActive = ref.watch(activeSessionIdProvider) == session.id;

    // On ne lit l'état du lecteur que si la séance est active (évite de créer
    // un notifier pour chaque carte de la liste).
    PlayerStatus? status;
    if (isActive) {
      status = ref.watch(playerProvider(session.id).select((s) => s.status));
    }
    final isLoaded =
        status == PlayerStatus.playing || status == PlayerStatus.paused;
    final isPlaying = status == PlayerStatus.playing;

    // Tap sur le corps de la carte : si la séance tourne déjà, on ouvre le
    // lecteur en cours (sans repasser par la préparation) ; sinon on lance.
    void handleCardTap() {
      HapticFeedback.mediumImpact();
      if (isLoaded) {
        context.push(AppRoutes.playerPath(session.id));
      } else {
        onTap();
      }
    }

    // Tap sur le bouton rond : si la séance tourne déjà, play/pause ; sinon
    // on lance la séance.
    void handleButtonTap() {
      HapticFeedback.lightImpact();
      if (isLoaded) {
        ref.read(playerProvider(session.id).notifier).togglePlayPause();
      } else {
        onTap();
      }
    }

    final semanticsLabel = !isLoaded
        ? 'Lancer ${session.title}, ${session.durationLabel}'
        : isPlaying
            ? 'Mettre en pause ${session.title}'
            : 'Reprendre ${session.title}';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: handleCardTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: const Border(
              left: BorderSide(color: AppColors.accent, width: 3),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingMd,
            vertical: AppConstants.spacingMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingXs),
                    Row(
                      children: [
                        const Icon(
                          Iconsax.timer_1,
                          size: 13,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppConstants.spacingXs),
                        Text(
                          session.durationLabel,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.accent,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingMd),
              // Bouton rond avec son propre tap (n'enclenche pas le tap de la
              // carte grâce à behavior: opaque).
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: handleButtonTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Iconsax.pause : Iconsax.play,
                    color: AppColors.background,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
