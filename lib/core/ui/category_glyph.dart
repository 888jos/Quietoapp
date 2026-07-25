import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Motif de catégorie dessiné en code : forme simple turquoise avec un
/// léger halo, dans la direction artistique Quieto (nuit, lueur douce).
/// Remplace les emojis. Si la catégorie n'a pas de motif, on retombe
/// sur l'emoji passé en secours.
class CategoryGlyph extends StatelessWidget {
  final String categoryId;
  final String fallbackEmoji;
  final double size;

  const CategoryGlyph({
    super.key,
    required this.categoryId,
    required this.fallbackEmoji,
    required this.size,
  });

  static const _supported = {
    'decouverte',
    'express',
    'actualite',
    'stress',
    'sleep',
    'breathing',
    'emotion',
  };

  @override
  Widget build(BuildContext context) {
    if (!_supported.contains(categoryId)) {
      return Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.62));
    }
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(categoryId),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final String id;

  _GlyphPainter(this.id);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;

    // Halo doux derrière la forme, puis la forme nette par-dessus.
    final glow = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09);
    final fill = Paint()..color = AppColors.accent;
    final stroke = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round;
    final glowStroke = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09);

    switch (id) {
      case 'decouverte':
        _paintMeditation(canvas, s, glow, fill);
      case 'express':
        _paintBolt(canvas, s, glow, fill);
      case 'actualite':
        _paintNewspaper(canvas, s, glow, fill);
      case 'stress':
        _paintKnot(canvas, s, glowStroke, stroke);
      case 'sleep':
        _paintMoon(canvas, s, glow, fill);
      case 'breathing':
        _paintSpiral(canvas, s, glowStroke, stroke);
      case 'emotion':
        _paintHeart(canvas, s, glow, fill);
    }
  }

  /// Silhouette assise en méditation : tête + buste + jambes croisées.
  void _paintMeditation(Canvas canvas, double s, Paint glow, Paint fill) {
    final path = Path()
      // Tête
      ..addOval(
        Rect.fromCircle(center: Offset(0.5 * s, 0.24 * s), radius: 0.11 * s),
      )
      // Buste en cloche
      ..moveTo(0.32 * s, 0.68 * s)
      ..cubicTo(0.32 * s, 0.44 * s, 0.40 * s, 0.38 * s, 0.50 * s, 0.38 * s)
      ..cubicTo(0.60 * s, 0.38 * s, 0.68 * s, 0.44 * s, 0.68 * s, 0.68 * s)
      ..close()
      // Jambes croisées : base large arrondie
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(0.18 * s, 0.62 * s, 0.82 * s, 0.78 * s),
          Radius.circular(0.08 * s),
        ),
      );
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
  }

  /// Éclair.
  void _paintBolt(Canvas canvas, double s, Paint glow, Paint fill) {
    final path = Path()
      ..moveTo(0.58 * s, 0.10 * s)
      ..lineTo(0.28 * s, 0.55 * s)
      ..lineTo(0.47 * s, 0.55 * s)
      ..lineTo(0.42 * s, 0.90 * s)
      ..lineTo(0.72 * s, 0.44 * s)
      ..lineTo(0.53 * s, 0.44 * s)
      ..close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
  }

  /// Journal plié : page pleine, titres évidés.
  void _paintNewspaper(Canvas canvas, double s, Paint glow, Paint fill) {
    final page = RRect.fromRectAndRadius(
      Rect.fromLTRB(0.20 * s, 0.26 * s, 0.80 * s, 0.74 * s),
      Radius.circular(0.06 * s),
    );
    canvas.drawRRect(page, glow);
    canvas.drawRRect(page, fill);

    // Contenu évidé (couleur du fond) : gros titre + deux lignes.
    final hole = Paint()..color = AppColors.background;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.28 * s, 0.34 * s, 0.56 * s, 0.46 * s),
        Radius.circular(0.02 * s),
      ),
      hole,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.28 * s, 0.53 * s, 0.72 * s, 0.58 * s),
        Radius.circular(0.02 * s),
      ),
      hole,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.28 * s, 0.63 * s, 0.72 * s, 0.68 * s),
        Radius.circular(0.02 * s),
      ),
      hole,
    );
  }

  /// Nœud qui se dénoue : pelote emmêlée avec un fil qui s'échappe.
  void _paintKnot(Canvas canvas, double s, Paint glowStroke, Paint stroke) {
    final path = Path()
      ..moveTo(0.24 * s, 0.62 * s)
      ..cubicTo(0.06 * s, 0.42 * s, 0.34 * s, 0.12 * s, 0.50 * s, 0.32 * s)
      ..cubicTo(0.64 * s, 0.50 * s, 0.36 * s, 0.68 * s, 0.28 * s, 0.46 * s)
      ..cubicTo(0.20 * s, 0.24 * s, 0.62 * s, 0.16 * s, 0.64 * s, 0.42 * s)
      ..cubicTo(0.65 * s, 0.58 * s, 0.72 * s, 0.64 * s, 0.86 * s, 0.64 * s);
    canvas.drawPath(path, glowStroke);
    canvas.drawPath(path, stroke);
  }

  /// Croissant de lune.
  void _paintMoon(Canvas canvas, double s, Paint glow, Paint fill) {
    final path = Path.combine(
      PathOperation.difference,
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(0.48 * s, 0.5 * s), radius: 0.32 * s),
        ),
      Path()
        ..addOval(
          Rect.fromCircle(center: Offset(0.62 * s, 0.40 * s), radius: 0.28 * s),
        ),
    );
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
  }

  /// Spirale de souffle.
  void _paintSpiral(Canvas canvas, double s, Paint glowStroke, Paint stroke) {
    final path = Path();
    const turns = 2.25;
    const steps = 60;
    final center = Offset(0.5 * s, 0.5 * s);
    final maxR = 0.32 * s;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = turns * 2 * math.pi * t - math.pi / 2;
      final r = maxR * t;
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, glowStroke);
    canvas.drawPath(path, stroke);
  }

  /// Cœur.
  void _paintHeart(Canvas canvas, double s, Paint glow, Paint fill) {
    final path = Path()
      ..moveTo(0.50 * s, 0.82 * s)
      ..cubicTo(0.16 * s, 0.58 * s, 0.20 * s, 0.28 * s, 0.40 * s, 0.26 * s)
      ..cubicTo(0.46 * s, 0.25 * s, 0.50 * s, 0.30 * s, 0.50 * s, 0.35 * s)
      ..cubicTo(0.50 * s, 0.30 * s, 0.54 * s, 0.25 * s, 0.60 * s, 0.26 * s)
      ..cubicTo(0.80 * s, 0.28 * s, 0.84 * s, 0.58 * s, 0.50 * s, 0.82 * s)
      ..close();
    canvas.drawPath(path, glow);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.id != id;
}
