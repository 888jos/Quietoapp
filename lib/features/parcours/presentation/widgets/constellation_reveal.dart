import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// La position de l'étoile du jour [i] (0..6) dans une zone [size].
/// C'est LA géométrie de la constellation du programme : la révélation
/// (constellation voyageuse) et le hero de la page programme utilisent
/// exactement cette fonction → quand la voyageuse se pose sur le hero,
/// chaque étoile tombe pile sur son double, aucun décalage au remplacement.
Offset positionEtoileConstellation(int i, Size size) {
  // Léger désordre déterministe (une constellation, pas un collier de
  // perles), proportionnel à la hauteur → même silhouette à toute taille.
  const jitter = [6.0, -9.0, 3.0, -6.0, 8.0, -4.0, 5.0];
  final u = i / 6;
  return Offset(
    (0.08 + 0.84 * u) * size.width,
    size.height * 0.60 -
        math.sin(math.pi * u) * size.height * 0.26 +
        jitter[i] * (size.height / 110),
  );
}

/// Le label J1..J7 sous une étoile : même rendu dans la révélation et le
/// hero (taille, graisse, décalage), pour un remplacement invisible.
void peindreLabelJour(Canvas canvas, Offset pos, int jour, double alpha) {
  final label = TextPainter(
    text: TextSpan(
      text: 'J$jour',
      style: TextStyle(
        color: Colors.white.withValues(alpha: alpha),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  label.paint(canvas, pos + Offset(-label.width / 2, 12));
}

/// La révélation du programme : 7 étoiles s'allument une à une le long d'un
/// arc et se relient d'un trait turquoise, comme une constellation qu'on
/// dessine (J1..J7). Même langage visuel que le ciel de l'app : halo flou +
/// cœur blanc (technique des têtes d'étoiles filantes de StarryBackground).
class ConstellationReveal extends StatefulWidget {
  final VoidCallback? onDone;

  const ConstellationReveal({super.key, this.onDone});

  @override
  State<ConstellationReveal> createState() => _ConstellationRevealState();
}

class _ConstellationRevealState extends State<ConstellationReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ConstellationPainter(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ConstellationPainter extends CustomPainter {
  _ConstellationPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  Offset _pos(int i, Size size) => positionEtoileConstellation(i, size);

  @override
  void paint(Canvas canvas, Size size) {
    // p balaie 0..7.7 : l'étoile i s'allume à t=i, le trait la rejoint juste
    // après. Tout est fini un peu avant la fin (respiration finale).
    final p = anim.value * 7.7;

    // ── Les traits, segment par segment ──────────────────
    for (var i = 0; i < 6; i++) {
      final part = ((p - i - 0.55) / 0.65).clamp(0.0, 1.0);
      if (part <= 0) continue;
      final a = _pos(i, size);
      final b = _pos(i + 1, size);
      final fin = Offset.lerp(a, b, part)!;
      // Halo du trait, puis cœur net.
      canvas.drawLine(
        a,
        fin,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.18)
          ..strokeWidth = 3.4
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4),
      );
      canvas.drawLine(
        a,
        fin,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.55)
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
    }

    // ── Les étoiles + labels J1..J7 ──────────────────────
    for (var i = 0; i < 7; i++) {
      final local = ((p - i) / 0.9).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final pos = _pos(i, size);
      // Pulse à l'arrivée : le halo gonfle puis se pose.
      final pulse = 1.0 + 0.7 * math.sin(math.pi * local.clamp(0.0, 1.0));
      final alpha = Curves.easeOut.transform(local);

      canvas.drawCircle(
        pos,
        9.0 * pulse,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.30 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        pos,
        3.4,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.55 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        pos,
        1.8,
        Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha),
      );

      peindreLabelJour(canvas, pos, i + 1, 0.8 * alpha);
    }
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) => false;
}
