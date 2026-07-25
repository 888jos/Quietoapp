import 'dart:math' show pi, sin;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../explore/explore_providers.dart';
import '../player_providers.dart';

/// Écran de lancement d'une séance depuis la conversation avec Louane.
///
/// Le rituel avant la séance, en un seul geste fluide :
///  1. le cover apparaît en douceur au centre, halo respirant derrière,
///     anneaux qui s'élargissent comme une onde calme ;
///  2. le contour du cover se trace en turquoise (la « jauge » qui charge,
///     satisfaisante à regarder) pendant que Louane pose deux mots ;
///  3. contour bouclé → petite pulsation lumineuse + haptique, puis fondu
///     vers le player : le cover vole à sa place (Hero), l'audio démarre.
///
/// Durée totale ~2,9 s : assez pour se poser, jamais une attente.
class LancementSeancePage extends ConsumerStatefulWidget {
  final String sessionId;

  const LancementSeancePage({super.key, required this.sessionId});

  @override
  ConsumerState<LancementSeancePage> createState() =>
      _LancementSeancePageState();
}

class _LancementSeancePageState extends ConsumerState<LancementSeancePage>
    with TickerProviderStateMixin {
  /// Chronologie principale (entrée → traçage → éclat), jouée une fois.
  late final AnimationController _fil;

  /// Ondes et halo, en boucle tant que l'écran vit.
  late final AnimationController _ondes;

  bool _parti = false; // navigation déclenchée (jamais deux fois)

  // Les temps forts de la chronologie (fractions de _dureeTotale).
  static const _dureeTotale = Duration(milliseconds: 2900);
  static const _entree = Interval(0.0, 0.14, curve: Curves.easeOutCubic);
  static const _trace = Interval(0.12, 0.88, curve: Curves.easeInOutCubic);
  static const _eclat = Interval(0.88, 1.0, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _fil = AnimationController(vsync: this, duration: _dureeTotale);
    _ondes = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _fil.addStatusListener((status) {
      if (status != AnimationStatus.completed || _parti || !mounted) return;
      _parti = true;
      // Le contour vient de boucler : l'instant « c'est prêt ».
      HapticFeedback.mediumImpact();
      // Fondu vers le player (via=lancement → transition douce, pas la
      // montée en feuille) ; le Hero fait glisser le cover à sa place.
      context.pushReplacement(
        '${AppRoutes.playerPath(widget.sessionId)}?via=lancement',
      );
    });

    // La pulsation au moment où le contour boucle.
    _fil.addListener(() {
      final t = _fil.value;
      if (t >= 0.86 && !_hapticTraceFaite) {
        _hapticTraceFaite = true;
        HapticFeedback.lightImpact();
      }
    });

    _fil.forward();
  }

  bool _hapticTraceFaite = false;

  @override
  void dispose() {
    _fil.dispose();
    _ondes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider(widget.sessionId));

    if (session == null) {
      // Séance introuvable (ne devrait pas arriver : id validé en amont).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    // Garde premium (même filet que PreparationPage : un lien direct vers
    // une séance payante sans abonnement part au paywall, sans animation).
    if (ref.watch(sessionLockedProvider(session))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.pushReplacement(AppRoutes.paywallDepuis('louane_seance'));
        }
      });
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    const tailleCover = 200.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fil, _ondes]),
          builder: (context, _) {
            final entree = _entree.transform(_fil.value);
            final trace = _trace.transform(_fil.value);
            final eclat = _eclat.transform(_fil.value);
            // Respiration du halo : un souffle lent, ample au traçage.
            final souffle =
                0.5 + 0.5 * sin(_ondes.value * 2 * pi - pi / 2);

            return Stack(
              alignment: Alignment.center,
              children: [
                // ── Ondes calmes qui s'élargissent depuis le centre ──
                CustomPaint(
                  size: Size.infinite,
                  painter: _OndesCalmesPainter(
                    avancement: _ondes.value,
                    visibilite: entree,
                  ),
                ),

                // ── Cover + halo + contour qui se trace ──
                Opacity(
                  opacity: entree,
                  child: Transform.scale(
                    scale: 0.92 + 0.08 * entree + 0.03 * eclat,
                    child: Container(
                      width: tailleCover,
                      height: tailleCover,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          // Halo respirant, qui s'embrase à l'éclat final.
                          BoxShadow(
                            color: AppColors.accent.withValues(
                              alpha: 0.14 +
                                  0.10 * souffle +
                                  0.30 * eclat,
                            ),
                            blurRadius: 40 + 14 * souffle + 30 * eclat,
                            spreadRadius: 4 + 3 * souffle + 8 * eclat,
                          ),
                        ],
                      ),
                      child: CustomPaint(
                        // Le contour se trace par-dessus le cover.
                        foregroundPainter: _ContourPainter(
                          avancement: trace,
                          eclat: eclat,
                        ),
                        child: Hero(
                          tag: 'seance-cover-${session.id}',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: session.imageFile != null
                                ? Image.asset(
                                    'assets/images/${session.imageFile}',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, e, stack) =>
                                        const _CoverVide(),
                                  )
                                : const _CoverVide(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Titre + durée sous le cover ──
                Positioned(
                  top: MediaQuery.of(context).size.height / 2 +
                      tailleCover / 2 -
                      10,
                  left: 32,
                  right: 32,
                  child: Opacity(
                    opacity: entree,
                    child: Column(
                      children: [
                        Text(
                          session.title,
                          style: AppTextStyles.titleLarge,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.durationLabel,
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Le mot de Louane, qui change à mi-chemin ──
                Positioned(
                  bottom: 72,
                  left: 32,
                  right: 32,
                  child: Opacity(
                    opacity: entree,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        _fil.value < 0.5
                            ? 'Louane te prépare ta séance'
                            : 'Installe-toi confortablement…',
                        key: ValueKey(_fil.value < 0.5),
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CoverVide extends StatelessWidget {
  const _CoverVide();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.accentDim,
      child: const Icon(Icons.music_note_rounded,
          size: 64, color: AppColors.accent),
    );
  }
}

/// Le contour arrondi du cover qui se trace en turquoise, du sommet jusqu'à
/// boucler : la jauge de chargement, mais posée sur la séance elle-même.
class _ContourPainter extends CustomPainter {
  final double avancement; // 0 → 1 : longueur tracée
  final double eclat; // 0 → 1 : pulsation finale (contour qui s'illumine)

  _ContourPainter({required this.avancement, required this.eclat});

  @override
  void paint(Canvas canvas, Size size) {
    if (avancement <= 0) return;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    final chemin = Path()..addRRect(rrect);
    final metrique = chemin.computeMetrics().first;
    final longueur = metrique.length;

    // Départ au milieu du bord haut (le path d'un RRect commence après le
    // coin haut-gauche → on décale d'un quart de bord haut environ).
    final depart = longueur * 0.115;
    final fin = depart + longueur * avancement;

    final peinture = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent.withValues(alpha: 0.85 + 0.15 * eclat);

    if (fin <= longueur) {
      canvas.drawPath(metrique.extractPath(depart, fin), peinture);
    } else {
      canvas.drawPath(metrique.extractPath(depart, longueur), peinture);
      canvas.drawPath(metrique.extractPath(0, fin - longueur), peinture);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter old) =>
      old.avancement != avancement || old.eclat != eclat;
}

/// Trois anneaux concentriques qui naissent au centre, s'élargissent
/// lentement et s'effacent : l'onde d'un caillou dans l'eau, au ralenti.
class _OndesCalmesPainter extends CustomPainter {
  final double avancement; // boucle 0 → 1
  final double visibilite; // 0 → 1 (l'entrée de l'écran)

  _OndesCalmesPainter({required this.avancement, required this.visibilite});

  @override
  void paint(Canvas canvas, Size size) {
    if (visibilite <= 0) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final rayonMax = size.shortestSide * 0.72;

    for (var i = 0; i < 3; i++) {
      final phase = (avancement + i / 3) % 1.0;
      final rayon = 110 + (rayonMax - 110) * phase;
      // Naît discret, s'affirme, s'évanouit au loin.
      final vie = phase < 0.15
          ? phase / 0.15
          : 1 - (phase - 0.15) / 0.85;
      final peinture = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = AppColors.accent
            .withValues(alpha: 0.16 * vie * visibilite);
      canvas.drawCircle(centre, rayon, peinture);
    }
  }

  @override
  bool shouldRepaint(_OndesCalmesPainter old) =>
      old.avancement != avancement || old.visibilite != visibilite;
}
