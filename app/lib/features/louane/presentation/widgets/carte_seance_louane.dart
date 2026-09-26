import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router.dart';
import '../../../../core/services/storage_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../explore/explore_providers.dart';
import '../../../player/player_providers.dart';
import '../louane_palette.dart';

/// La carte qui accompagne une bulle de Louane quand elle lance une séance
/// ([LouaneMessage.seanceId]). Cover, titre, durée, bouton play qui respire.
/// Un tap ouvre l'écran de lancement (animation) puis le player.
///
/// [nouvelle] : la carte vient d'arriver → entrée douce (fondu + glissée),
/// jouée une seule fois, légèrement après le POP de la bulle.
class CarteSeanceLouane extends ConsumerStatefulWidget {
  final String seanceId;
  final bool nouvelle;

  const CarteSeanceLouane({
    super.key,
    required this.seanceId,
    this.nouvelle = false,
  });

  @override
  ConsumerState<CarteSeanceLouane> createState() => _CarteSeanceLouaneState();
}

class _CarteSeanceLouaneState extends ConsumerState<CarteSeanceLouane>
    with TickerProviderStateMixin {
  late final AnimationController _entree;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _entree = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    // La bulle POP d'abord (340 ms), la carte arrive juste derrière : la
    // petite attente rend l'arrivée naturelle, comme un second geste.
    if (widget.nouvelle) {
      Future.delayed(const Duration(milliseconds: 260), () {
        if (mounted) _entree.forward();
      });
    } else {
      _entree.value = 1.0;
    }
    // Le bouton play respire en continu : l'invitation au tap, sans mots.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entree.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _lancer() {
    final session = ref.read(currentSessionProvider(widget.seanceId));
    if (session == null) return;
    HapticFeedback.lightImpact();
    ref.read(vigieProvider).log('louane_seance_lancee', {
      'seance': session.id,
      'categorie': session.categoryId,
    });
    // Verrou premium : une séance payante sans abonnement part au paywall
    // (pas d'animation de lancement pour un contenu verrouillé).
    if (ref.read(sessionLockedProvider(session))) {
      context.push(AppRoutes.paywallDepuis('louane_seance'));
      return;
    }
    context.push(AppRoutes.lancementPath(session.id));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider(widget.seanceId));
    // Séance absente du catalogue local (app pas à jour) : pas de carte,
    // le texte de Louane reste une jolie suggestion en mots.
    if (session == null) return const SizedBox.shrink();

    final largeurMax = MediaQuery.of(context).size.width * 0.78;
    final categorie = ref.watch(categoryByIdProvider(session.categoryId));

    final carte = Container(
      constraints: BoxConstraints(maxWidth: largeurMax),
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: LouanePalette.accent.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: LouanePalette.accent.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _lancer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Cover : le même visuel que le player, en miniature.
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: session.imageFile != null
                        ? Image.asset(
                            'assets/images/${session.imageFile}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, e, stack) =>
                                const _MiniCoverPlaceholder(),
                          )
                        : const _MiniCoverPlaceholder(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: AppTextStyles.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        categorie != null
                            ? '${session.durationLabel} · ${categorie.name}'
                            : session.durationLabel,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Play qui respire : halo qui s'étire doucement.
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) {
                    final t = Curves.easeInOut.transform(_pulse.value);
                    return Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: LouanePalette.accent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: LouanePalette.accent
                                .withValues(alpha: 0.25 + 0.25 * t),
                            blurRadius: 10 + 8 * t,
                            spreadRadius: 1 + 2 * t,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.background,
                        size: 26,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _entree,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_entree.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      },
      child: Align(alignment: Alignment.centerLeft, child: carte),
    );
  }
}

class _MiniCoverPlaceholder extends StatelessWidget {
  const _MiniCoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentDim,
      child: const Icon(Icons.music_note_rounded,
          color: AppColors.accent, size: 24),
    );
  }
}
