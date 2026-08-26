import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
/// le contenu glisse par-dessus. Le voile laiteux vit dans
/// shaders/stardust.frag (lueur qui ondule, teintée d'aurore vers le
/// haut) ; les micro-étoiles scintillent doucement par-dessus.
class StardustTrail extends StatefulWidget {
  /// Position verticale de l'arc, en fraction de la hauteur du canvas.
  /// 0.62 = valeur historique (petites bandes) ; la Home passe 0.8 avec un
  /// canvas haut pour laisser la lueur s'étirer vers l'aurore.
  final double arcRatio;

  const StardustTrail({super.key, this.arcRatio = 0.62});

  @override
  State<StardustTrail> createState() => _StardustTrailState();
}

class _StardustTrailState extends State<StardustTrail>
    with SingleTickerProviderStateMixin {
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/stardust.frag');

  final double _seed = math.Random().nextDouble() * 1000;
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    });
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (shader != null)
            CustomPaint(
              painter: _VeilPainter(shader, _time, _seed, widget.arcRatio),
              size: Size.infinite,
            ),
          CustomPaint(
            painter: _StardustPainter(_time, _seed, widget.arcRatio),
            size: Size.infinite,
          ),
        ],
      ),
    );
  }
}

/// Le voile laiteux, délégué au shader.
class _VeilPainter extends CustomPainter {
  _VeilPainter(this.shader, this.time, this.seed, this.arcRatio)
      : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final double seed;
  final double arcRatio;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, seed + time.value)
      ..setFloat(3, arcRatio);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_VeilPainter oldDelegate) => false;
}

/// Micro-étoiles denses près de l'arc, éparses au bord, qui respirent
/// chacune à son rythme (scintillement lent, jamais synchrone).
class _StardustPainter extends CustomPainter {
  _StardustPainter(this.time, this.seed, this.arcRatio)
      : super(repaint: time);

  final ValueNotifier<double> time;
  final double seed;
  final double arcRatio;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = seed + time.value;
    // Même arc que le voile (sans sa houle : les étoiles sont fixes).
    double mid(double u) => h * arcRatio - h * 0.10 * math.sin(math.pi * u);

    final rnd = math.Random(1214);
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      final u = rnd.nextDouble();
      // Écart vertical resserré autour de l'arc (moyenne de 2 tirages
      // → distribution en cloche, la traînée a un cœur dense).
      final spread = (rnd.nextDouble() + rnd.nextDouble() - 1) * 24;
      // Rythme propre à chaque étoile — tiré AVANT le filtre pour garder
      // la séquence stable quelle que soit la hauteur du canvas.
      final phase = rnd.nextDouble() * 2 * math.pi;
      final speed = 0.25 + rnd.nextDouble() * 0.45;
      final y = mid(u) + spread;
      if (y < 2 || y > h - 2) continue;
      final r = 0.4 + rnd.nextDouble() * 0.9;
      // Poussière blanche, avec quelques grains turquoise et ivoire.
      final tint = switch (rnd.nextInt(6)) {
        0 => AppColors.accent,
        1 => const Color(0xFFEFEAD8),
        _ => Colors.white,
      };
      final base = 0.10 + rnd.nextDouble() * 0.30;
      final twinkle = 0.72 + 0.28 * math.sin(t * speed + phase);
      paint.color = tint.withValues(alpha: base * twinkle);
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
  // Le ruban lui-même vit dans shaders/aurora.frag : une nappe de lumière
  // calculée pixel par pixel sur le GPU (dégradés parfaitement lisses,
  // formes pilotées par du bruit fractal, jamais périodiques). Le
  // programme est compilé une seule fois pour toute la vie de l'app.
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/aurora.frag');

  // Graine tirée au lancement : l'aurore ne reprend jamais deux fois au
  // même endroit du champ de bruit.
  final double _seed = math.Random().nextDouble() * 1000;
  final ValueNotifier<double> _time = ValueNotifier(0);
  late final Ticker _ticker;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    });
    _ticker = createTicker((elapsed) {
      _time.value = elapsed.inMicroseconds / 1e6;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    // Une frame de ciel nu le temps que le programme arrive : invisible,
    // le fond étoilé est déjà là.
    if (shader == null) return const SizedBox.expand();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraShaderPainter(shader, _time, _seed),
        size: Size.infinite,
      ),
    );
  }
}

class _AuroraShaderPainter extends CustomPainter {
  _AuroraShaderPainter(this.shader, this.time, this.seed)
      : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;
  final double seed;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, seed + time.value);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_AuroraShaderPainter oldDelegate) => false;
}
