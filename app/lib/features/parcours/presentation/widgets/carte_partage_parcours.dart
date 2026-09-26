import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/models/parcours_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'constellation_etat.dart';

/// La signature de la carte. Texte en dur : majuscule initiale, pas
/// d'emoji, pas de tiret long. Publique pour le test de style.
const kSignatureCartePartage =
    'Mon programme de la semaine,\ncréé pour moi par Louane';

/// La carte à partager en story (360 x 640 logiques, capturée en x3 =
/// 1080 x 1920) : le ciel de Quieto, « POUR {PRÉNOM} », le titre du
/// programme en serif, la constellation dans son état réel, et la
/// signature Quieto. Jamais montée à l'écran : rendue hors champ le temps
/// de la capture. Textes en dur : majuscule initiale, pas d'emoji, pas de
/// tiret long.
class CartePartageParcours extends StatelessWidget {
  final String prenom;
  final ParcoursModel parcours;

  const CartePartageParcours({
    super.key,
    required this.prenom,
    required this.parcours,
  });

  @override
  Widget build(BuildContext context) {
    final faits = {
      for (final j in parcours.jours)
        if (parcours.jourTermine(j.jour)) j.jour,
    };
    return Container(
      width: 360,
      height: 640,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.background, AppColors.cardSurface],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _CielCartePainter())),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 84, 28, 44),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (prenom.trim().isNotEmpty)
                  Text(
                    'POUR ${prenom.trim().toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.4,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  parcours.titre,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'CormorantGaramond',
                    fontSize: 31,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  height: 190,
                  child: CustomPaint(
                    painter: ConstellationEtatPainter(
                      pulse: const AlwaysStoppedAnimation(0.6),
                      faits: faits,
                      jourCourant: parcours.tousJoursTermines
                          ? 0
                          : parcours.jourCourant,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const Spacer(),
                Text(
                  kSignatureCartePartage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Quieto',
                      style: TextStyle(
                        fontFamily: 'CormorantGaramond',
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le ciel de la carte : des étoiles fixes, seedées (même carte à chaque
/// partage), dans l'esprit de StarryBackground mais sans animation.
class _CielCartePainter extends CustomPainter {
  const _CielCartePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final alea = math.Random(717);
    for (var i = 0; i < 70; i++) {
      final pos = Offset(
        alea.nextDouble() * size.width,
        alea.nextDouble() * size.height,
      );
      final rayon = 0.5 + alea.nextDouble() * 0.9;
      final alpha = 0.12 + alea.nextDouble() * 0.45;
      // Une étoile sur six tire vers le turquoise, comme le ciel de l'app.
      final teinte = i % 6 == 0 ? AppColors.accent : Colors.white;
      canvas.drawCircle(
          pos, rayon, Paint()..color = teinte.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_CielCartePainter oldDelegate) => false;
}
