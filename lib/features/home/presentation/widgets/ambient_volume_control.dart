import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/ambient_music.dart';
import '../../../../core/theme/app_colors.dart';

/// Petit contrôle discret de la musique d'ambiance (header de la home).
/// Repliée : une simple note de musique. Un tap déplie un mini curseur ;
/// glisser à 0 coupe la musique. Se replie tout seul après quelques secondes.
class AmbientVolumeControl extends ConsumerStatefulWidget {
  const AmbientVolumeControl({super.key});

  @override
  ConsumerState<AmbientVolumeControl> createState() =>
      _AmbientVolumeControlState();
}

class _AmbientVolumeControlState extends ConsumerState<AmbientVolumeControl> {
  bool _open = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
    _armHideTimer();
  }

  /// Referme le curseur après 3 s sans interaction.
  void _armHideTimer() {
    _hideTimer?.cancel();
    if (!_open) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _open = false);
    });
  }

  /// Referme le curseur dès qu'on touche n'importe où ailleurs sur la page.
  void _close() {
    if (!_open) return;
    _hideTimer?.cancel();
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    final level = ref.watch(ambientLevelProvider);
    final muted = level == 0;

    return TapRegion(
      onTapOutside: (_) => _close(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        // Pastille ronde façon bouton, même repliée : fond, liseré et une
        // pointe de turquoise pour qu'on la repère sans qu'elle crie.
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _open
                ? AppColors.accent.withValues(alpha: 0.45)
                : AppColors.textPrimary.withValues(alpha: 0.14),
          ),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_open) ...[
                // Stop / lecture : coupe la musique d'un tap, la relance au
                // dernier volume choisi.
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(ambientLevelProvider.notifier).toggleMute();
                    _armHideTimer();
                  },
                  tooltip: muted ? 'Relancer la musique' : 'Stopper la musique',
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 40),
                  icon: Icon(
                    muted ? Icons.play_arrow_rounded : Icons.stop_rounded,
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 40,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      activeTrackColor: AppColors.accent,
                      inactiveTrackColor:
                          AppColors.textPrimary.withValues(alpha: 0.15),
                      thumbColor: AppColors.accent,
                      thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: level,
                      onChanged: (v) {
                        ref.read(ambientLevelProvider.notifier).set(v);
                        _armHideTimer();
                      },
                      onChangeEnd: (v) {
                        if (v == 0) HapticFeedback.lightImpact();
                        ref.read(ambientLevelProvider.notifier).commit();
                        _armHideTimer();
                      },
                    ),
                  ),
                ),
              ],
              IconButton(
                onPressed: _toggle,
                tooltip: muted ? 'Musique coupée' : 'Musique d\'ambiance',
                iconSize: 21,
                icon: Icon(
                  muted ? Icons.music_off_rounded : Icons.music_note_rounded,
                  color: muted
                      ? AppColors.textPrimary.withValues(alpha: 0.4)
                      : AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
