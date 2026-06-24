import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../louane_palette.dart';

/// Le personnage de Louane, dessiné en code : un visage rond et doux sur un
/// ciel étoilé calme. Elle respire, flotte, cligne des yeux, lève parfois les
/// yeux au ciel (rêveuse), et suit du regard une étoile filante qui passe.
///
/// `compact` = version mini (quand le clavier est ouvert, pour libérer la place).
/// Tout est auto-contenu ici. Le jour où tu as un perso Rive, on remplace juste
/// ce widget — rien d'autre ne bouge.
class LouanePersonnage extends StatefulWidget {
  final bool parle;
  final bool ecoute;
  final bool compact;

  /// Quand true, le perso ne dessine PAS son propre ciel (un ciel pleine page
  /// est affiché derrière, en mode oral).
  final bool sansCiel;

  const LouanePersonnage({
    super.key,
    this.parle = false,
    this.ecoute = false,
    this.compact = false,
    this.sansCiel = false,
  });

  @override
  State<LouanePersonnage> createState() => _LouanePersonnageState();
}

class _LouanePersonnageState extends State<LouanePersonnage>
    with TickerProviderStateMixin {
  late final AnimationController _breath; // respiration
  late final AnimationController _twinkle; // scintillement étoiles
  late final AnimationController _float; // flottement vertical
  late final AnimationController _blink; // clignement
  late final AnimationController _ring; // ondes quand elle écoute
  late final AnimationController _shoot; // étoile filante

  Timer? _timerBlink;
  Timer? _timerEvent;
  final _rng = math.Random();

  bool _reveuse = false;
  bool _shootActif = false;
  Offset _shootStart = Offset.zero;
  Offset _shootEnd = Offset.zero;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _twinkle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat();
    _float = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600))
      ..repeat(reverse: true);
    _ring = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _blink =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _shoot =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _planifieClignement();
    _planifieEvenement();
  }

  @override
  void dispose() {
    _timerBlink?.cancel();
    _timerEvent?.cancel();
    _breath.dispose();
    _twinkle.dispose();
    _float.dispose();
    _ring.dispose();
    _blink.dispose();
    _shoot.dispose();
    super.dispose();
  }

  // ── Petites réactions ───────────────────────────────────
  void _planifieClignement() {
    _timerBlink =
        Timer(Duration(milliseconds: 2800 + _rng.nextInt(3200)), () async {
      if (!mounted) return;
      await _blink.forward(from: 0);
      if (mounted) await _blink.reverse();
      _planifieClignement();
    });
  }

  void _planifieEvenement() {
    _timerEvent =
        Timer(Duration(milliseconds: 7000 + _rng.nextInt(8000)), () async {
      if (!mounted) return;
      if (_rng.nextBool()) {
        await _reverie();
      } else {
        await _etoileFilante();
      }
      _planifieEvenement();
    });
  }

  Future<void> _reverie() async {
    if (!mounted) return;
    setState(() => _reveuse = true);
    await Future.delayed(const Duration(milliseconds: 2400));
    if (mounted) setState(() => _reveuse = false);
  }

  Future<void> _etoileFilante() async {
    if (!mounted) return;
    final depuisGauche = _rng.nextBool();
    _shootStart =
        Offset(depuisGauche ? 0.04 : 0.96, 0.06 + _rng.nextDouble() * 0.14);
    _shootEnd =
        Offset(depuisGauche ? 0.70 : 0.30, 0.42 + _rng.nextDouble() * 0.16);
    setState(() => _shootActif = true);
    await _shoot.forward(from: 0);
    if (mounted) setState(() => _shootActif = false);
  }

  /// Direction du regard : suit l'étoile filante, ou lève les yeux quand rêveuse.
  Offset get _gaze {
    if (_shootActif) {
      final head = Offset.lerp(_shootStart, _shootEnd, _shoot.value)!;
      return Offset(
        (head.dx - 0.5).clamp(-1.0, 1.0),
        (head.dy - 0.42).clamp(-1.0, 0.4),
      );
    }
    if (_reveuse) return const Offset(0.18, -0.7);
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return widget.compact ? _buildCompact() : _buildPlein();
  }

  Widget _buildCompact() {
    return SizedBox(
      height: 66,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_breath, _blink]),
          builder: (context, _) {
            final breath = Curves.easeInOut.transform(_breath.value);
            return Transform.scale(
              scale: 1.0 + 0.03 * breath,
              child: CustomPaint(
                size: const Size(54, 54),
                painter: _VisagePainter(
                  parle: widget.parle,
                  ecoute: false,
                  breath: breath,
                  blink: _blink.value,
                  gaze: Offset.zero,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlein() {
    return SizedBox(
      height: 190,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ciel étoilé local (masqué en mode oral : un ciel pleine page est
          // déjà affiché derrière le personnage).
          if (!widget.sansCiel)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_twinkle, _shoot]),
                builder: (context, _) => CustomPaint(
                  painter: _CielEtoile(
                    t: _twinkle.value,
                    shootActif: _shootActif,
                    shootProgress: _shoot.value,
                    shootStart: _shootStart,
                    shootEnd: _shootEnd,
                  ),
                ),
              ),
            ),
          // Le visage
          AnimatedBuilder(
            animation: Listenable.merge([_breath, _float, _blink, _ring, _shoot]),
            builder: (context, _) {
              final breath = Curves.easeInOut.transform(_breath.value);
              final floatY = (_float.value - 0.5) * 7;
              return Transform.translate(
                offset: Offset(0, floatY),
                child: Transform.scale(
                  scale: 1.0 + 0.03 * breath,
                  child: CustomPaint(
                    size: const Size(160, 160),
                    painter: _VisagePainter(
                      parle: widget.parle,
                      ecoute: widget.ecoute,
                      breath: breath,
                      blink: _blink.value,
                      gaze: _gaze,
                      ring: _ring.value,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Ciel étoilé pleine page (fond du mode oral) : champ d'étoiles dense qui
/// scintille, avec des étoiles filantes occasionnelles, étalé sur tout l'écran.
class CielEtoileFond extends StatefulWidget {
  const CielEtoileFond({super.key});

  @override
  State<CielEtoileFond> createState() => _CielEtoileFondState();
}

class _CielEtoileFondState extends State<CielEtoileFond>
    with TickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final AnimationController _shoot;
  Timer? _timerShoot;
  final _rng = math.Random();

  bool _shootActif = false;
  Offset _shootStart = Offset.zero;
  Offset _shootEnd = Offset.zero;

  // Champ d'étoiles dense, généré une seule fois (positions stables).
  late final List<(double, double, double)> _etoiles;

  @override
  void initState() {
    super.initState();
    final r = math.Random(42);
    _etoiles = List.generate(
      70,
      (_) => (r.nextDouble(), r.nextDouble(), 0.8 + r.nextDouble() * 1.3),
    );
    _twinkle = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4000))
      ..repeat();
    _shoot = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _planifieShoot();
  }

  void _planifieShoot() {
    _timerShoot =
        Timer(Duration(milliseconds: 6000 + _rng.nextInt(9000)), () async {
      if (!mounted) return;
      final depuisGauche = _rng.nextBool();
      _shootStart =
          Offset(depuisGauche ? 0.04 : 0.96, 0.05 + _rng.nextDouble() * 0.30);
      _shootEnd =
          Offset(depuisGauche ? 0.75 : 0.25, 0.35 + _rng.nextDouble() * 0.40);
      setState(() => _shootActif = true);
      await _shoot.forward(from: 0);
      if (mounted) setState(() => _shootActif = false);
      _planifieShoot();
    });
  }

  @override
  void dispose() {
    _timerShoot?.cancel();
    _twinkle.dispose();
    _shoot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_twinkle, _shoot]),
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _CielEtoile(
          t: _twinkle.value,
          shootActif: _shootActif,
          shootProgress: _shoot.value,
          shootStart: _shootStart,
          shootEnd: _shootEnd,
          etoiles: _etoiles,
        ),
      ),
    );
  }
}

class _CielEtoile extends CustomPainter {
  final double t;
  final bool shootActif;
  final double shootProgress;
  final Offset shootStart;
  final Offset shootEnd;
  final List<(double, double, double)> etoiles;

  const _CielEtoile({
    required this.t,
    required this.shootActif,
    required this.shootProgress,
    required this.shootStart,
    required this.shootEnd,
    this.etoiles = _etoilesParDefaut,
  });

  static const _etoilesParDefaut = <(double, double, double)>[
    (0.08, 0.18, 1.4), (0.18, 0.42, 1.0), (0.27, 0.12, 1.8),
    (0.36, 0.30, 1.0), (0.45, 0.10, 1.2), (0.55, 0.20, 1.6),
    (0.63, 0.08, 1.0), (0.72, 0.28, 1.3), (0.82, 0.14, 1.7),
    (0.90, 0.36, 1.1), (0.12, 0.62, 1.0), (0.30, 0.74, 1.3),
    (0.50, 0.82, 1.0), (0.68, 0.70, 1.5), (0.86, 0.64, 1.0),
    (0.05, 0.40, 1.0), (0.95, 0.52, 1.2), (0.40, 0.58, 0.9),
    (0.60, 0.52, 0.9), (0.22, 0.88, 1.1), (0.78, 0.90, 1.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (var i = 0; i < etoiles.length; i++) {
      final e = etoiles[i];
      final tw =
          0.3 + 0.5 * (0.5 + 0.5 * math.sin((t + i * 0.13) * 2 * math.pi));
      p.color = Colors.white.withValues(alpha: tw * 0.75);
      canvas.drawCircle(Offset(e.$1 * size.width, e.$2 * size.height), e.$3, p);
    }

    // Étoile filante
    if (shootActif) {
      final head = Offset(
        ui.lerpDouble(shootStart.dx, shootEnd.dx, shootProgress)! * size.width,
        ui.lerpDouble(shootStart.dy, shootEnd.dy, shootProgress)! * size.height,
      );
      final dir = Offset(
        (shootEnd.dx - shootStart.dx) * size.width,
        (shootEnd.dy - shootStart.dy) * size.height,
      );
      final tail = head - dir * 0.20;
      final op = math.sin(shootProgress * math.pi); // 0 → 1 → 0
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(tail, head, [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: op),
          ]),
      );
      canvas.drawCircle(head, 2, Paint()..color = Colors.white.withValues(alpha: op));
    }
  }

  @override
  bool shouldRepaint(covariant _CielEtoile old) =>
      old.t != t ||
      old.shootActif != shootActif ||
      old.shootProgress != shootProgress;
}

class _VisagePainter extends CustomPainter {
  final bool parle;
  final bool ecoute;
  final double breath;
  final double blink;
  final Offset gaze;
  final double ring;

  _VisagePainter({
    required this.parle,
    required this.ecoute,
    required this.breath,
    required this.blink,
    required this.gaze,
    this.ring = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.26;

    // 1. Ondes d'écoute
    if (ecoute) {
      for (var k = 0; k < 2; k++) {
        final prog = (ring + k * 0.5) % 1.0;
        final rr = r + prog * r * 1.7;
        final op = (1 - prog) * 0.32;
        canvas.drawCircle(
          c,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = LouanePalette.accent.withValues(alpha: op),
        );
      }
    }

    // 2. Lueur douce
    final glowOp = (parle ? 0.5 : 0.28) + 0.15 * breath;
    canvas.drawCircle(
      c,
      r * 1.05,
      Paint()
        ..color = LouanePalette.accent.withValues(alpha: glowOp)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );

    // 3. Visage (dégradé radial corail)
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFF8C3AC), LouanePalette.accent],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // 4. Yeux (clignement + regard)
    final yeux = Paint()..color = AppColors.background;
    final eyeR = r * 0.10;
    final eyeH = math.max(1.5, eyeR * 2 * (1 - blink));
    final gazePx = Offset(gaze.dx * r * 0.13, gaze.dy * r * 0.10);
    for (final s in [-1.0, 1.0]) {
      final ec = c + Offset(s * r * 0.42, -r * 0.12) + gazePx;
      canvas.drawOval(
        Rect.fromCenter(center: ec, width: eyeR * 2, height: eyeH),
        yeux,
      );
    }

    // 5. Sourire doux
    canvas.drawArc(
      Rect.fromCircle(center: c + Offset(0, r * 0.06), radius: r * 0.42),
      0.35,
      2.44,
      false,
      Paint()
        ..color = AppColors.background
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.07
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VisagePainter old) =>
      old.parle != parle ||
      old.ecoute != ecoute ||
      old.breath != breath ||
      old.blink != blink ||
      old.gaze != gaze ||
      old.ring != ring;
}
