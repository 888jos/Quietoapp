import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/boutons_connexion.dart';
import '../../../core/ui/starry_background.dart';
import 'widgets/slide_reveal.dart';

/// Première page de l'onboarding : créer son compte (Apple sur iPhone,
/// Google partout), structurée comme les grands (illustration, titre,
/// boutons officiels). Jamais bloquant : « Continuer sans compte » mène
/// au même parcours, la connexion reste possible depuis le profil.
class OnboardingConnexionPage extends ConsumerStatefulWidget {
  /// Mode aperçu (bouton de test dans le profil) : tous les boutons
  /// referment simplement la page, rien n'est compté dans les stats.
  final bool preview;

  const OnboardingConnexionPage({super.key, this.preview = false});

  @override
  ConsumerState<OnboardingConnexionPage> createState() =>
      _OnboardingConnexionPageState();
}

class _OnboardingConnexionPageState
    extends ConsumerState<OnboardingConnexionPage> {
  // Bouton en cours ('apple' ou 'google'), pour n'animer que lui.
  String? _enCours;

  @override
  void initState() {
    super.initState();
    if (!widget.preview) {
      ref.read(vigieProvider).log('onboarding_etape', {'etape': 'connexion'});
    }
  }

  Future<void> _connexion(String fournisseur) async {
    if (widget.preview) {
      context.pop();
      return;
    }
    if (_enCours != null) return;
    setState(() => _enCours = fournisseur);
    final auth = ref.read(authServiceProvider);
    final resultat = fournisseur == 'apple'
        ? await auth.connexionApple()
        : await auth.connexionGoogle();
    if (!mounted) return;
    setState(() => _enCours = null);

    switch (resultat) {
      case AuthResultat.ok:
        ref
            .read(vigieProvider)
            .log('onboarding_connexion', {'choix': fournisseur});
        context.go(AppRoutes.onboarding);
      case AuthResultat.annule:
        break;
      case AuthResultat.erreur:
        // On prévient en douceur, sans jamais bloquer l'entrée dans l'app.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.cardSurface,
            elevation: 0,
            margin: const EdgeInsets.all(AppConstants.spacingMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              side: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.25),
              ),
            ),
            content: Text(
              'La connexion n\'a pas fonctionné. Tu peux réessayer, '
              'ou continuer sans compte.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
        );
    }
  }

  void _sansCompte() {
    if (widget.preview) {
      context.pop();
      return;
    }
    ref
        .read(vigieProvider)
        .log('onboarding_connexion', {'choix': 'sans_compte'});
    context.go(AppRoutes.onboarding);
  }

  /// Déjà connecté (retour en arrière depuis le quiz, par exemple) : on
  /// continue simplement, pas de deuxième connexion.
  void _continuer() {
    if (widget.preview) {
      context.pop();
      return;
    }
    ref
        .read(vigieProvider)
        .log('onboarding_connexion', {'choix': 'deja_connecte'});
    context.go(AppRoutes.onboarding);
  }

  @override
  Widget build(BuildContext context) {
    final appleDisponible = ref.read(authServiceProvider).appleDisponible;
    // Suit l'état de connexion en direct : si la personne revient sur cette
    // page déjà connectée, on ne lui repropose pas de se connecter.
    final compte = ref.watch(utilisateurProvider).value;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 3),
                  const SlideReveal(
                    active: true,
                    child: Center(child: _SceneCalme()),
                  ),
                  const Spacer(flex: 2),
                  SlideReveal(
                    active: true,
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      'Bienvenue sur Quieto',
                      style: AppTextStyles.displayLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  SlideReveal(
                    active: true,
                    delay: const Duration(milliseconds: 260),
                    child: Text(
                      compte == null
                          ? 'Ton espace pour respirer et te poser.\n'
                              'Crée ton compte pour garder ta progression '
                              'avec toi.'
                          : 'Ton espace pour respirer et te poser.\n'
                              'Ton compte est prêt, ta progression te suit.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(flex: 3),
                  if (compte == null) ...[
                    SlideReveal(
                      active: true,
                      delay: const Duration(milliseconds: 380),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (appleDisponible) ...[
                            BoutonConnexionApple(
                              isLoading: _enCours == 'apple',
                              onTap: () => _connexion('apple'),
                            ),
                            const SizedBox(
                                height: AppConstants.spacingSm + 2),
                          ],
                          BoutonConnexionGoogle(
                            isLoading: _enCours == 'google',
                            onTap: () => _connexion('google'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    SlideReveal(
                      active: true,
                      delay: const Duration(milliseconds: 470),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _sansCompte,
                        child: const Padding(
                          padding: EdgeInsets.all(AppConstants.spacingSm),
                          child: Text(
                            'Continuer sans compte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Déjà connecté : pas de deuxième connexion, on rassure
                    // et on continue.
                    SlideReveal(
                      active: true,
                      delay: const Duration(milliseconds: 380),
                      child: Text(
                        '✓ Connecté avec '
                        '${compte.email ?? compte.displayName ?? 'ton compte'}',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.accent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    SlideReveal(
                      active: true,
                      delay: const Duration(milliseconds: 440),
                      child: AppButton(label: 'Continuer', onTap: _continuer),
                    ),
                    const SizedBox(height: AppConstants.spacingMd),
                    SlideReveal(
                      active: true,
                      delay: const Duration(milliseconds: 500),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () async {
                          ref.read(vigieProvider).log(
                              'onboarding_connexion', {'choix': 'autre_compte'});
                          // La déconnexion réaffiche les boutons (le flux
                          // utilisateurProvider reconstruit la page).
                          await ref.read(authServiceProvider).deconnexion();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(AppConstants.spacingSm),
                          child: Text(
                            'Utiliser un autre compte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppConstants.spacingSm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// La scène animée : un orbe qui respire au centre (écho des exercices de
// respiration), une lune et un nuage qui flottent, des étoiles qui
// scintillent. Tous les mouvements sont lents et amples, esprit Quieto.
// ─────────────────────────────────────────────────────────

class _SceneCalme extends StatefulWidget {
  const _SceneCalme();

  @override
  State<_SceneCalme> createState() => _SceneCalmeState();
}

class _SceneCalmeState extends State<_SceneCalme>
    with TickerProviderStateMixin {
  // Le souffle : 6 secondes par cycle, comme une vraie respiration calme.
  late final AnimationController _souffle;
  // La dérive : 14 secondes, pour les flottements et les scintillements.
  late final AnimationController _derive;

  @override
  void initState() {
    super.initState();
    _souffle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _derive = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _souffle.dispose();
    _derive.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 260,
      child: AnimatedBuilder(
        animation: Listenable.merge([_souffle, _derive]),
        builder: (context, _) {
          final s = _souffle.value; // 0..1, cycle de respiration
          final d = _derive.value; // 0..1, cycle lent de dérive
          double flotte(double phase, double ampleur) =>
              math.sin((d + phase) * 2 * math.pi) * ampleur;
          double scintille(double phase) =>
              0.35 + 0.55 * (0.5 + 0.5 * math.sin((d * 3 + phase) * 2 * math.pi));

          return Stack(
            alignment: Alignment.center,
            // Sans ça, tout ce qui dépasse du cadre de la scène (halo de la
            // lune, lueurs, ondes) est coupé net : on voyait une bordure.
            clipBehavior: Clip.none,
            children: [
              // Louane et ses ondes, au centre de la scène.
              CustomPaint(
                size: const Size(190, 190),
                painter: _OrbePainter(souffle: s),
              ),
              // La lune, dans le coin haut droit, qui flotte doucement.
              Positioned(
                top: 0 + flotte(0.0, 7),
                right: 2,
                child: Transform.rotate(
                  angle: -0.35 + flotte(0.25, 0.03),
                  child: const CustomPaint(
                    size: Size(64, 64),
                    painter: _LunePainter(),
                  ),
                ),
              ),
              // Le grand nuage, en bas à gauche, qui dérive lentement.
              Positioned(
                left: 0 + flotte(0.5, 10),
                bottom: 10,
                child: const CustomPaint(
                  size: Size(98, 38),
                  painter: _NuagePainter(),
                ),
              ),
              // Un second nuage plus discret, en haut à gauche, qui dérive
              // en sens inverse pour donner de la profondeur.
              Positioned(
                left: 16 + flotte(0.15, -8),
                top: 26,
                child: Opacity(
                  opacity: 0.55,
                  child: const CustomPaint(
                    size: Size(66, 26),
                    painter: _NuagePainter(),
                  ),
                ),
              ),
              // Les étoiles, poussées vers les bords, qui scintillent
              // chacune à leur rythme.
              Positioned(
                left: 14,
                top: 74,
                child: _Etoile(taille: 18, opacite: scintille(0.0)),
              ),
              Positioned(
                right: 18,
                bottom: 62,
                child: _Etoile(taille: 15, opacite: scintille(0.4)),
              ),
              Positioned(
                right: 66,
                top: 20,
                child: _Etoile(taille: 10, opacite: scintille(0.55)),
              ),
              Positioned(
                left: 78,
                bottom: 26,
                child: _Etoile(taille: 11, opacite: scintille(0.7)),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Louane au centre de la scène : son visage (le même que dans le chat,
/// dégradé turquoise, yeux et sourire) qui gonfle et dégonfle sur
/// 6 secondes, entouré d'ondes qui naissent à son bord et s'évanouissent
/// en s'élargissant, comme des cercles à la surface de l'eau.
class _OrbePainter extends CustomPainter {
  final double souffle; // 0..1

  const _OrbePainter({required this.souffle});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // Le rayon respire : +8 % au sommet de l'inspiration.
    final respiration = 0.5 + 0.5 * math.sin(souffle * 2 * math.pi);
    final rayon = size.width * 0.22 * (1 + 0.08 * respiration);

    // Le halo, en deux couches : une lueur turquoise dense près d'elle,
    // qui se fond en un voile lavande très léger vers l'extérieur. Le tout
    // s'intensifie à l'inspiration.
    canvas.drawCircle(
      centre,
      rayon * 2.8,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.accent.withValues(alpha: 0.30 + 0.10 * respiration),
            AppColors.accent.withValues(alpha: 0.10),
            const Color(0xFF8E7CF0).withValues(alpha: 0.06),
            const Color(0xFF8E7CF0).withValues(alpha: 0),
          ],
          stops: const [0, 0.4, 0.7, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: rayon * 2.8)),
    );

    // Un liseré lumineux flouté juste au bord du visage, comme une lueur
    // qui l'enveloppe, plus vive au sommet de l'inspiration.
    canvas.drawCircle(
      centre,
      rayon * 1.12,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color =
            AppColors.accent.withValues(alpha: 0.30 + 0.20 * respiration),
    );

    // Deux ondes décalées d'un demi-cycle : il y en a toujours une visible.
    for (var i = 0; i < 2; i++) {
      final p = (souffle + i * 0.5) % 1.0;
      canvas.drawCircle(
        centre,
        rayon * (1.1 + p * 1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.accent.withValues(alpha: (1 - p) * 0.35),
      );
    }

    // Louane : même dégradé que son avatar dans le chat.
    final cadre = Rect.fromCircle(center: centre, radius: rayon);
    canvas.drawCircle(
      centre,
      rayon,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB6F2EC), AppColors.accent],
        ).createShader(cadre),
    );

    // Son visage, aux mêmes proportions que dans le chat : les yeux et le
    // sourire suivent la respiration puisqu'ils sont dessinés dans le cercle.
    final s = rayon * 2;
    final origine = centre - Offset(rayon, rayon);
    final traits = Paint()..color = AppColors.background;
    canvas.drawCircle(
      origine + Offset(s * 0.38, s * 0.44), s * 0.045, traits);
    canvas.drawCircle(
      origine + Offset(s * 0.62, s * 0.44), s * 0.045, traits);
    canvas.drawArc(
      Rect.fromCircle(
        center: origine + Offset(s * 0.5, s * 0.5),
        radius: s * 0.17,
      ),
      0.3,
      2.54,
      false,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_OrbePainter oldDelegate) =>
      oldDelegate.souffle != souffle;
}

/// Un croissant de lune d'or pâle, avec un léger halo chaud.
class _LunePainter extends CustomPainter {
  const _LunePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const couleur = Color(0xFFF3E3AF);
    final r = size.width / 2;
    final centre = Offset(r, r);

    canvas.drawCircle(
      centre,
      r * 1.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            couleur.withValues(alpha: 0.18),
            couleur.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: r * 1.6)),
    );

    // Le croissant : le disque plein, moins un disque décalé vers le
    // haut-droit qui vient « croquer » la lune.
    final croissant = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: centre, radius: r * 0.82)),
      Path()
        ..addOval(
          Rect.fromCircle(
            center: centre + Offset(r * 0.42, -r * 0.30),
            radius: r * 0.72,
          ),
        ),
    );
    canvas.drawPath(croissant, Paint()..color = couleur.withValues(alpha: 0.95));
  }

  @override
  bool shouldRepaint(_LunePainter oldDelegate) => false;
}

/// Un petit nuage discret, à peine plus clair que le fond.
class _NuagePainter extends CustomPainter {
  const _NuagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final peinture = Paint()..color = Colors.white.withValues(alpha: 0.12);
    final h = size.height;
    final nuage = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, h * 0.45, size.width, h * 0.55),
          Radius.circular(h * 0.35),
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.32, h * 0.42),
          radius: h * 0.42,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.62, h * 0.36),
          radius: h * 0.50,
        ),
      );
    canvas.drawPath(nuage, peinture);
  }

  @override
  bool shouldRepaint(_NuagePainter oldDelegate) => false;
}

/// Une étoile à quatre branches qui scintille (son opacité varie).
class _Etoile extends StatelessWidget {
  final double taille;
  final double opacite;

  const _Etoile({required this.taille, required this.opacite});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacite.clamp(0.0, 1.0),
      child: CustomPaint(
        size: Size.square(taille),
        painter: const _EtoilePainter(),
      ),
    );
  }
}

class _EtoilePainter extends CustomPainter {
  const _EtoilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    // Quatre branches reliées par des courbes rentrantes : la forme
    // « étincelle » classique.
    final etoile = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.12, c.dy - r * 0.12, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.12, c.dy + r * 0.12, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.12, c.dy + r * 0.12, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.12, c.dy - r * 0.12, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(etoile, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(_EtoilePainter oldDelegate) => false;
}
