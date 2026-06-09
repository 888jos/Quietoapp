import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../app/router.dart';
import '../../player_providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionId = ref.watch(activeSessionIdProvider);
    if (sessionId == null) return const SizedBox.shrink();

    final status = ref.watch(
      playerProvider(sessionId).select((s) => s.status),
    );

    // Only show when playing or paused (not idle, loading, error)
    if (status == PlayerStatus.idle || status == PlayerStatus.error) {
      return const SizedBox.shrink();
    }

    final session = ref.watch(currentSessionProvider(sessionId));
    if (session == null) return const SizedBox.shrink();

    final isPlaying = status == PlayerStatus.playing;
    final notifier = ref.read(playerProvider(sessionId).notifier);

    return GestureDetector(
      onTap: () => context.push(AppRoutes.playerPath(sessionId)),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingMd),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(
            top: BorderSide(color: AppColors.accentDim, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.title,
                style: AppTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: notifier.togglePlayPause,
              icon: Icon(
                isPlaying ? Iconsax.pause : Iconsax.play,
                color: AppColors.accent,
                size: 24,
              ),
            ),
            IconButton(
              onPressed: () async {
                // stop() relâche le keepAlive : le notifier sera détruit par
                // l'autoDispose une fois le mini player caché. Pas besoin
                // d'invalider (ça recréait le provider et relançait l'audio).
                await notifier.stop();
                ref.read(activeSessionIdProvider.notifier).state = null;
              },
              icon: const Icon(
                Iconsax.stop,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
