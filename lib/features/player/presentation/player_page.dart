import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_scaffold.dart';
import '../player_providers.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final String sessionId;

  const PlayerPage({super.key, required this.sessionId});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void initState() {
    super.initState();
    // Discard any cached PlayerNotifier so each visit creates a fresh one
    // with a properly initialised AudioPlayer for this session.
    ref.invalidate(playerProvider(widget.sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    final session = ref.watch(currentSessionProvider(sessionId));

    if (session == null) {
      return AppScaffold(
        body: Center(
          child: Text('Séance introuvable.',
              style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final playerState = ref.watch(playerProvider(sessionId));
    final notifier = ref.read(playerProvider(sessionId).notifier);

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
                    onPressed: () => Navigator.of(context).pop(),
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

              // Cover placeholder
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: AppColors.accentDim,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusXl),
                ),
                child: const Icon(Iconsax.music,
                    size: 80, color: AppColors.accent),
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
          onPressed: onBackward,
          icon: const Icon(Iconsax.backward_15_seconds,
              color: AppColors.textPrimary, size: 32),
        ),
        const SizedBox(width: AppConstants.spacingXl),

        // Play/Pause
        GestureDetector(
          onTap: isLoading ? null : onToggle,
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
                    isPlaying
                        ? Iconsax.pause
                        : Iconsax.play,
                    color: AppColors.background,
                    size: 32,
                  ),
          ),
        ),
        const SizedBox(width: AppConstants.spacingXl),

        // +15s
        IconButton(
          onPressed: onForward,
          icon: const Icon(Iconsax.forward_15_seconds,
              color: AppColors.textPrimary, size: 32),
        ),
      ],
    );
  }
}
