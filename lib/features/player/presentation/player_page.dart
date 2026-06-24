import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/error_placeholder.dart';
import '../../profile/profile_providers.dart';
import '../player_providers.dart';

class PlayerPage extends ConsumerWidget {
  final String sessionId;

  const PlayerPage({super.key, required this.sessionId});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Après la PREMIÈRE séance terminée : propose le rappel quotidien, une
  /// seule fois, au moment où ça a du sens (l'utilisateur vient de méditer,
  /// il est détendu — c'est là que la permission est acceptée, pas à froid
  /// au démarrage).
  Future<void> _maybeOfferReminder(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    if (storage.notificationsEnabled || storage.notificationPromptShown) {
      return;
    }
    await storage.setNotificationPromptShown();

    // « Demain à la même heure » : l'heure à laquelle il vient de méditer
    // est, par définition, une heure qui marche pour lui.
    final time = TimeOfDay.now();
    final timeLabel =
        '${time.hour}h${time.minute.toString().padLeft(2, '0')}';
    final firstName = storage.firstName;

    if (!context.mounted) return;
    final accepted = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(
          firstName.isEmpty ? 'Belle séance 🌿' : 'Belle séance, $firstName 🌿',
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Tu veux qu\'on te rappelle demain vers $timeLabel ?\n'
            'Un rappel doux, jamais insistant.',
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Plus tard'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oui, volontiers'),
          ),
        ],
      ),
    );
    if (accepted != true) return;

    final granted =
        await ref.read(notificationServiceProvider).requestPermission();
    if (!granted) return;
    // skipToday : il vient de méditer, le premier rappel part demain.
    await ref
        .read(profileProvider.notifier)
        .enableReminderAt(time, skipToday: true);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider(sessionId));

    if (session == null) {
      return AppScaffold(
        body: ErrorPlaceholder(
          message: 'Séance introuvable.',
          onRetry: () => context.go(AppRoutes.home),
          retryLabel: 'Retour à l\'accueil',
        ),
      );
    }

    // Garde premium : le verrou des cartes (onTap) ne suffit pas — un deep
    // link /player/<id_premium> doit aussi renvoyer au paywall. Le check se
    // fait AVANT de watcher playerProvider, sinon l'auto-play démarre l'audio.
    final isSubscribed = ref.watch(subscriptionProvider);
    if (session.isPremium && !isSubscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pushReplacement(AppRoutes.paywallSlide);
      });
      return const AppScaffold(body: SizedBox.shrink());
    }

    // Fin de séance (playing → idle) : propose le rappel quotidien si c'est
    // la première séance terminée et que rien n'a encore été proposé.
    ref.listen<PlayerState>(playerProvider(sessionId), (prev, next) {
      if (prev?.status == PlayerStatus.playing &&
          next.status == PlayerStatus.idle) {
        _maybeOfferReminder(context, ref);
      }
    });

    final playerState = ref.watch(playerProvider(sessionId));
    final notifier = ref.read(playerProvider(sessionId).notifier);

    if (playerState.status == PlayerStatus.error) {
      return AppScaffold(
        body: ErrorPlaceholder(
          message: playerState.error ?? 'Impossible de charger la séance.',
          onRetry: notifier.retry,
          icon: Icons.headset_off,
        ),
      );
    }

    return AppScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingLg),
          child: Column(
            children: [
              // App bar custom
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(
                      AppRoutes.categoryPath(session.categoryId),
                    ),
                    tooltip: 'Retour',
                    icon: const Icon(Iconsax.arrow_left_2,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text('Méditation', style: AppTextStyles.bodyMedium),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const Spacer(),

              // Cover
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusXl),
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      AppConstants.radiusXl - 2),
                  child: session.imageFile != null
                      ? Image.asset(
                          'assets/images/${session.imageFile}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, e, stack) =>
                              _CoverPlaceholder(),
                        )
                      : _CoverPlaceholder(),
                ),
              ),

              const SizedBox(height: AppConstants.spacingXl),

              // Titre
              Text(session.title,
                  style: AppTextStyles.titleLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppConstants.spacingXs),
              Text(
                playerState.duration > Duration.zero
                    ? _formatDuration(playerState.duration)
                    : '',
                style: AppTextStyles.badge,
              ),

              const Spacer(),

              // Barre de progression
              _ProgressBar(
                progress: playerState.progress,
                position: playerState.position,
                duration: playerState.duration,
                onSeek: (v) => notifier.seekTo(
                  Duration(
                      milliseconds:
                          (v * playerState.duration.inMilliseconds).round()),
                ),
              ),

              const SizedBox(height: AppConstants.spacingXl),

              // Contrôles
              _PlayerControls(
                status: playerState.status,
                onToggle: notifier.togglePlayPause,
                onForward: notifier.skipForward,
                onBackward: notifier.skipBackward,
              ),

              const SizedBox(height: AppConstants.spacingXxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _ProgressBar({
    required this.progress,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accent,
            inactiveTrackColor: AppColors.accentDim,
            thumbColor: AppColors.accent,
            overlayColor: AppColors.accentDim,
            trackHeight: 3,
            thumbShape:
                const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: progress.clamp(0.0, 1.0),
            onChanged: onSeek,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_format(position), style: AppTextStyles.caption),
              Text(_format(duration), style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlayerControls extends StatelessWidget {
  final PlayerStatus status;
  final VoidCallback onToggle;
  final VoidCallback onForward;
  final VoidCallback onBackward;

  const _PlayerControls({
    required this.status,
    required this.onToggle,
    required this.onForward,
    required this.onBackward,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = status == PlayerStatus.loading;
    final isPlaying = status == PlayerStatus.playing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -15s
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onBackward();
          },
          tooltip: 'Reculer de 15 secondes',
          icon: const Icon(Iconsax.backward_15_seconds,
              color: AppColors.textPrimary, size: 32),
        ),
        const SizedBox(width: AppConstants.spacingXl),

        // Play/Pause
        Semantics(
          button: true,
          label: isPlaying ? 'Mettre en pause' : 'Lancer la méditation',
          child: GestureDetector(
            onTap: isLoading
                ? null
                : () {
                    HapticFeedback.heavyImpact();
                    onToggle();
                  },
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: AppColors.background, strokeWidth: 2),
                    )
                  : Icon(
                      isPlaying ? Iconsax.pause : Iconsax.play,
                      color: AppColors.background,
                      size: 32,
                    ),
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingXl),

        // +15s
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            onForward();
          },
          tooltip: 'Avancer de 15 secondes',
          icon: const Icon(Iconsax.forward_15_seconds,
              color: AppColors.textPrimary, size: 32),
        ),
      ],
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 220,
      color: AppColors.accentDim,
      child: const Icon(Iconsax.music, size: 80, color: AppColors.accent),
    );
  }
}
