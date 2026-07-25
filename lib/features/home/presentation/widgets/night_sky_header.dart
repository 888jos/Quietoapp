import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import 'glowing_moon.dart';

/// Haut de la Home : la lune veille à droite, la salutation est posée au
/// centre. L'aurore boréale, elle, vit dans [AuroraSky], peinte au niveau
/// du fond de page (comme les étoiles) pour se dissoudre jusque derrière
/// la barre d'état sans jamais être coupée.
class NightSkyHeader extends StatelessWidget {
  final String greeting;

  const NightSkyHeader({super.key, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: Stack(
        children: [
          const Positioned(
            top: 14,
            right: AppConstants.spacingMd,
            child: GlowingMoon(size: 96),
          ),
          // La salutation, en haut à gauche. Cadrée pour ne jamais passer
          // sous la lune : un prénom long revient à la ligne (2 max), et
          // au-delà on coupe proprement avec « … ».
          Positioned(
            left: AppConstants.spacingLg,
            right: 132,
            top: 34,
            child: Text(
              greeting,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'CormorantGaramond',
                fontSize: 42,
                fontVariations: [ui.FontVariation('wght', 620)],
                color: AppColors.textPrimary,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Poussière d'étoiles : une traînée façon voie lactée qui traverse le bas
/// de la scène en arc léger. Comme l'aurore, elle vit dans le Stack de la
/// Home, au niveau du fond de page : elle reste en place quand on défile,
/// le contenu glisse par-dessus.
class StardustTrail extends StatelessWidget {
  const StardustTrail({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: _StardustPainter(), size: Size.infinite),
    );
  }
}

/// Micro-étoiles denses + voile laiteux très doux (dégradés radiaux,
/// aucun flou). Statique → zéro coût.
class _StardustPainter extends CustomPainter {
  const _StardustPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Ligne médiane de la traînée : un arc doux, plus haut au centre.
    double mid(double u) => h * 0.62 - 10 * math.sin(math.pi * u);

    // Voile laiteux : quelques nappes très transparentes le long de l'arc.
    for (var i = 0; i < 4; i++) {
      final u = (i + 0.5) / 4;
      final center = Offset(u * w, mid(u));
      final radius = w * 0.19;
      final paint = Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          [
            Colors.white.withValues(alpha: 0.055),
            Colors.white.withValues(alpha: 0.025),
            Colors.white.withValues(alpha: 0.0),
          ],
          [0.0, 0.55, 1.0],
        );
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 22 / radius);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawCircle(center, radius, paint);
      canvas.restore();
    }

    // Micro-étoiles : denses près de la ligne médiane, éparses au bord.
    final rnd = math.Random(1214);
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      final u = rnd.nextDouble();
      // Écart vertical resserré autour de l'arc (moyenne de 2 tirages
      // → distribution en cloche, la traînée a un cœur dense).
      final spread = (rnd.nextDouble() + rnd.nextDouble() - 1) * 24;
      final y = mid(u) + spread;
      if (y < 2 || y > h - 2) continue;
      final r = 0.4 + rnd.nextDouble() * 0.9;
      // Poussière blanche, avec quelques grains turquoise et ivoire.
      final tint = switch (rnd.nextInt(6)) {
        0 => AppColors.accent,
        1 => const Color(0xFFEFEAD8),
        _ => Colors.white,
      };
      paint.color =
          tint.withValues(alpha: 0.10 + rnd.nextDouble() * 0.30);
      canvas.drawCircle(Offset(u * w, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StardustPainter oldDelegate) => false;
}

/// L'aurore boréale du fond de page : à poser dans le Stack de la Home,
/// au-dessus du ciel étoilé, SANS SafeArea → elle monte jusque derrière
/// la barre d'état et fond dans le ciel sans aucune coupure.
class AuroraSky extends StatefulWidget {
  const AuroraSky({super.key});

  @override
  State<AuroraSky> createState() => _AuroraSkyState();
}

class _AuroraSkyState extends State<AuroraSky>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _AuroraPainter(_c), size: Size.infinite),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  // Palette d'aurore : base vert-turquoise (l'oxygène), sommet violet.
  static const _green = Color(0xFF4FE8A8);
  static const _teal = AppColors.accent; // turquoise Quieto
  static const _violet = Color(0xFF8F7BE8);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final t = anim.value; // 0..1, continu

    // Ligne médiane du ruban : ondulation lente qui traverse le ciel.
    // Le canvas part du HAUT de l'écran (derrière la barre d'état) :
    // l'altitude intègre donc ~50 px de zone d'état.
    double base(double u) {
      return 165 +
          12 * math.sin(2 * math.pi * (0.8 * u + t)) +
          6 * math.sin(2 * math.pi * (1.9 * u - 2 * t) + 1.3);
    }

    // Luminosité locale : des nappes brillantes qui GLISSENT le long du
    // ruban (produit de deux ondes → taches de lumière mouvantes).
    double brightness(double u) {
      final a = math.sin(2 * math.pi * (2.2 * u + 2 * t));
      final b = math.sin(2 * math.pi * (1.1 * u - t) + 2.0);
      return 0.45 + 0.55 * (0.5 + 0.5 * a * b);
    }

    // Respiration de la hauteur du ruban.
    double breath(double u) {
      return 0.85 + 0.15 * math.sin(2 * math.pi * (1.4 * u + t) + 2.0);
    }

    // ── Le ruban : uniquement des halos doux qui se chevauchent.
    // Aucun chemin, aucun contour, aucune découpe → tout fond dans le
    // ciel, comme une aquarelle. Trois couches : vert lumineux au cœur
    // bas, turquoise au milieu, violet dissous au sommet. ──
    const columns = 18;
    for (var i = 0; i < columns; i++) {
      final u = i / (columns - 1);
      final x = u * w;
      final y = base(u);
      final b = brightness(u);
      final k = breath(u);

      // Cœur vert, bas du ruban.
      _glow(canvas, Offset(x, y - 16 * k), 120, 95 * k, _green, 0.11 * b);
      // Corps turquoise.
      _glow(canvas, Offset(x, y - 56 * k), 140, 115 * k, _teal, 0.075 * b);
      // Sommet violet, presque évaporé.
      _glow(canvas, Offset(x, y - 102 * k), 150, 120 * k, _violet,
          0.045 * (0.6 + 0.4 * b));
    }
  }

  /// Tache de lumière douce (dégradé radial étiré verticalement).
  void _glow(Canvas canvas, Offset center, double width, double height,
      Color color, double alpha) {
    final radius = width / 2;
    final paint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.5),
          color.withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, height / width);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawCircle(center, radius, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuroraPainter oldDelegate) => false;
}
