import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Ciel étoilé doux et CONTINU (même esprit que le paywall) : les étoiles
/// scintillent lentement sans jamais « sauter », et quelques étoiles filantes
/// traversent de temps en temps. Isolé dans un RepaintBoundary.
class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with TickerProviderStateMixin {
  // Scintillement : période longue. Les vitesses des étoiles sont ENTIÈRES
  // (voir _Star.speed) → au rebouclage 1→0 l'angle reste continu, aucun cut.
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  // Étoiles filantes : période longue → elles reviennent posément et lentement.
  late final AnimationController _shooting = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _twinkle.dispose();
    _shooting.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _StarsPainter(_twinkle, _shooting),
        size: Size.infinite,
      ),
    );
  }
}

class _Star {
  final double x, y, r, phase;
  final int speed; // nombre ENTIER de cycles par période → continuité parfaite
  const _Star(this.x, this.y, this.r, this.phase, this.speed);
}

class _Shooting {
  final double t0; // départ (fraction 0..1 de la période)
  final double dur; // durée active (fraction)
  final double x, y; // point de départ (fraction écran)
  final double dx, dy; // direction normalisée
  final Color color; // blanc ou turquoise (~1 sur 3)
  const _Shooting(
      this.t0, this.dur, this.x, this.y, this.dx, this.dy, this.color);
}

class _StarsPainter extends CustomPainter {
  _StarsPainter(this.twinkle, this.shooting)
      : super(repaint: Listenable.merge([twinkle, shooting]));

  final Animation<double> twinkle;
  final Animation<double> shooting;

  // Étoiles générées une fois (seed fixe → même ciel à chaque frame).
  static final List<_Star> _stars = () {
    final rnd = math.Random(717);
    return List.generate(75, (_) {
      return _Star(
        rnd.nextDouble(),
        rnd.nextDouble(),
        rnd.nextDouble() * 1.1 + 0.4,
        rnd.nextDouble() * 2 * math.pi,
        1 + rnd.nextInt(3), // 1, 2 ou 3 cycles/période
      );
    });
  }();

  // 5 étoiles filantes, TOUJOURS vers le bas-droite (angle presque constant),
  // départs variés (dont plein milieu d'écran), calmes et lentes, ~1/3 turquoise.
  static final List<_Shooting> _shootings = () {
    final rnd = math.Random(4242);
    return List.generate(5, (i) {
      // ~18° à 30° sous l'horizontale → même sens général, légère variation.
      final angle = 0.32 + rnd.nextDouble() * 0.20;
      return _Shooting(
        i / 5 + rnd.nextDouble() * 0.07, // départs bien étalés dans le temps
        0.14, // ~3,4 s active sur 24 s → lente
        rnd.nextDouble() * 0.55, // départ x : bord gauche jusqu'au milieu
        rnd.nextDouble() * 0.55, // départ y : haut jusqu'au milieu d'écran
        math.cos(angle),
        math.sin(angle),
        i % 3 == 0 ? AppColors.accent : Colors.white, // 1 sur 3 en turquoise
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    // ── Étoiles scintillantes ────────────────────────────────
    final t = twinkle.value; // 0..1, continu
    final paint = Paint();
    for (final s in _stars) {
      // angle = phase + speed*2π*t : au rebouclage t:1→0, la variation est un
      // multiple entier de 2π → aucune discontinuité visible.
      final a = 0.16 + 0.34 * (0.5 + 0.5 * math.sin(s.phase + s.speed * 2 * math.pi * t));
      paint.color = Colors.white.withValues(alpha: a);
      canvas.drawCircle(Offset(s.x * size.width, s.y * size.height), s.r, paint);
    }

    // ── Étoiles filantes ─────────────────────────────────────
    final st = shooting.value;
    for (final sh in _shootings) {
      final p = (st - sh.t0) / sh.dur;
      if (p < 0 || p > 1) continue;
      // enveloppe très douce : fade in/out progressif (sin², max faible).
      final env = math.pow(math.sin(p * math.pi), 1.6).toDouble();
      final travel = size.width * 0.55; // distance parcourue
      final trailLen = size.width * 0.24; // longueur de la traînée

      final dir = Offset(sh.dx, sh.dy); // sens du déplacement (bas-droite)
      final head = Offset(
        sh.x * size.width + sh.dx * travel * p,
        sh.y * size.height + sh.dy * travel * p,
      );
      final tail = head - dir * trailLen; // la queue traîne DERRIÈRE la tête
      final perp = Offset(-dir.dy, dir.dx); // perpendiculaire au déplacement
      const halfW = 2.6; // demi-largeur à la tête → traînée ample

      // Traînée en fuseau : large et lumineuse à la tête, pointue et
      // transparente à la queue (vraie forme de comète, pas un trait « têtard »).
      final path = Path()
        ..moveTo(head.dx + perp.dx * halfW, head.dy + perp.dy * halfW)
        ..lineTo(head.dx - perp.dx * halfW, head.dy - perp.dy * halfW)
        ..lineTo(tail.dx, tail.dy)
        ..close();
      final shader = ui.Gradient.linear(head, tail, [
        sh.color.withValues(alpha: 0.42 * env),
        sh.color.withValues(alpha: 0.0),
      ]);
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4), // douceur
      );

      // Tête : halo doux + petit cœur brillant (le « point » qui mène).
      canvas.drawCircle(
        head,
        3.2,
        Paint()
          ..color = sh.color.withValues(alpha: 0.30 * env)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      canvas.drawCircle(
        head,
        1.4,
        Paint()..color = Colors.white.withValues(alpha: 0.75 * env),
      );
    }
  }

  // Repeint en continu via `repaint:` ; pas de comparaison nécessaire.
  @override
  bool shouldRepaint(_StarsPainter old) => false;
}
