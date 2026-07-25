import 'package:flutter/material.dart';

/// Lune veilleuse du haut de la Home : croissant ivoire (couleur de lune)
/// dessiné en code, halo doux qui « respire » très lentement. Décoratif.
class GlowingMoon extends StatefulWidget {
  final double size;

  const GlowingMoon({super.key, this.size = 76});

  @override
  State<GlowingMoon> createState() => _GlowingMoonState();
}

class _GlowingMoonState extends State<GlowingMoon>
    with SingleTickerProviderStateMixin {
  // Respiration du halo : très lente pour rester apaisante.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _MoonPainter(_c),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.breath) : super(repaint: breath);

  final Animation<double> breath;

  // Couleur de lune : ivoire doux, légèrement chaud.
  static const _moon = Color(0xFFEFEAD8);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(0.5 * s, 0.5 * s);
    // 0..1 adouci (ease in-out) pour le halo.
    final t = Curves.easeInOut.transform(breath.value);

    // Halo extérieur qui respire.
    canvas.drawCircle(
      center,
      0.46 * s,
      Paint()
        ..color = _moon.withValues(alpha: 0.08 + 0.08 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.18 * s),
    );

    // Croissant : différence de deux cercles.
    final crescent = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(0.47 * s, 0.5 * s),
            radius: 0.30 * s,
          ),
        ),
      Path()
        ..addOval(
          Rect.fromCircle(
            center: Offset(0.61 * s, 0.41 * s),
            radius: 0.26 * s,
          ),
        ),
    );

    // Lueur proche du croissant, puis croissant net.
    canvas.drawPath(
      crescent,
      Paint()
        ..color = _moon.withValues(alpha: 0.35 + 0.15 * t)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.07 * s),
    );
    canvas.drawPath(crescent, Paint()..color = _moon);
  }

  @override
  bool shouldRepaint(_MoonPainter oldDelegate) => false;
}
