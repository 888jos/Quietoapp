import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme,
        CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../explore/explore_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/app_scaffold.dart';
import '../../../core/ui/error_placeholder.dart';
import '../../profile/profile_providers.dart';
import '../player_providers.dart';

class PlayerPage extends ConsumerWidget {
  final String sessionId;

  /// true quand on arrive par l'écran de lancement de Louane : la flèche
  /// retour ramène alors à la conversation (pop), pas à la page catégorie.
  final bool viaLancement;

  const PlayerPage({
    super.key,
    required this.sessionId,
    this.viaLancement = false,
  });

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Après la PREMIÈRE séance terminée : propose le rappel quotidien, une
  /// seule fois, au moment où ça a du sens (l'utilisateur vient de faire sa
  /// séance, il est détendu — c'est là que la permission est acceptée, pas à
  /// froid au démarrage). Il choisit lui-même l'heure du rappel ; le sélecteur
  /// démarre sur l'heure actuelle, qui marche par définition pour lui.
  Future<void> _maybeOfferReminder(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    if (storage.notificationsEnabled || storage.notificationPromptShown) {
      return;
    }
    await storage.setNotificationPromptShown();

    if (!context.mounted) return;
    final time = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusLg),
        ),
      ),
      builder: (_) => _ReminderOfferSheet(firstName: storage.firstName),
    );
    ref.read(vigieProvider).log('rappel_propose', {'accepte': time != null});
    if (time == null) return;

    final granted =
        await ref.read(notificationServiceProvider).requestPermission();
    ref.read(vigieProvider).log('rappel_permission', {'accordee': granted});
    if (!granted) return;
    // skipToday : il vient de faire sa séance, le premier rappel part demain.
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
    if (ref.watch(sessionLockedProvider(session))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.pushReplacement(AppRoutes.paywallDepuis('seance'));
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
                    // Venu du chat Louane : retour à la conversation (elle
                    // attend le ressenti). Sinon : la page de la catégorie.
                    onPressed: () => viaLancement && context.canPop()
                        ? context.pop()
                        : context.go(
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

              // Cover. Le Hero partage son tag avec l'écran de lancement
              // Louane : en arrivant par là, le cover glisse à sa place.
              Hero(
                tag: 'seance-cover-${session.id}',
                child: Container(
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

// ── Bottom sheet proposition de rappel (fin de 1ʳᵉ séance) ──
//
// Renvoie l'heure choisie via Navigator.pop, ou null si « Non merci » /
// glissé vers le bas. Même style que le sheet « Heure du rappel » du profil.

class _ReminderOfferSheet extends StatefulWidget {
  final String firstName;

  const _ReminderOfferSheet({required this.firstName});

  @override
  State<_ReminderOfferSheet> createState() => _ReminderOfferSheetState();
}

class _ReminderOfferSheetState extends State<_ReminderOfferSheet> {
  // Défaut : l'heure actuelle. Il vient de faire sa séance maintenant, donc
  // « demain à la même heure » est le meilleur point de départ.
  late TimeOfDay _selected;

  @override
  void initState() {
    super.initState();
    _selected = TimeOfDay.now();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingLg,
        AppConstants.spacingMd,
        AppConstants.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.firstName.isEmpty
                ? 'Belle séance 🌿'
                : 'Belle séance, ${widget.firstName} 🌿',
            style: AppTextStyles.titleMedium,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            'À quelle heure veux-tu prendre soin de toi demain ?',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          SizedBox(
            height: 180,
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                    2024, 1, 1, _selected.hour, _selected.minute),
                onDateTimeChanged: (dt) =>
                    _selected = TimeOfDay(hour: dt.hour, minute: dt.minute),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          AppButton(
            label: 'Oui, rappelle-moi',
            onTap: () => Navigator.of(context).pop(_selected),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Non merci',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
