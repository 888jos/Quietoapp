import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Le cercle qui « analyse » en fin de questionnaire : trois ondes lentes,
/// l'anneau de progression, et ce qu'on pose au centre (le pourcentage, puis
/// le visage de Louane).
///
/// Extrait pour être partagé par les deux fins d'onboarding : l'écran de
/// compréhension (Louane naît de ce cercle) et l'ancien écran de chargement
/// gardé derrière le drapeau. Un seul cercle, donc aucune dérive visuelle
/// possible entre les deux.
class CercleComprehension extends StatelessWidget {
  const CercleComprehension({
    super.key,
    required this.phaseOndes,
    required this.progression,
    required this.centre,
    this.opaciteOndes = 1,
    this.opaciteAnneau = 1,
  });

  /// Avance des ondes (0 → 1, en boucle).
  final double phaseOndes;

  /// Avance de l'anneau (0 → 1).
  final double progression;

  /// Ce qui vit au centre du cercle.
  final Widget centre;

  /// Effacement des ondes et de l'anneau — utilisé quand le visage prend
  /// la place du compteur : tout ce qui « travaillait » s'efface, seul le
  /// halo de Louane reste.
  final double opaciteOndes;
  final double opaciteAnneau;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (opaciteOndes > 0)
            Opacity(
              opacity: opaciteOndes.clamp(0, 1),
              child: CustomPaint(
                size: const Size(220, 220),
                painter: WavePainter(wavePhase: phaseOndes),
              ),
            ),
          if (opaciteAnneau > 0)
            Opacity(
              opacity: opaciteAnneau.clamp(0, 1),
              child: SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: progression,
                  color: AppColors.accent,
                  backgroundColor: AppColors.cardSurface,
                  strokeWidth: 8,
                ),
              ),
            ),
          centre,
        ],
      ),
    );
  }
}

// ── Painter : vagues concentriques ───────────────────────────────────────────

class WavePainter extends CustomPainter {
  final double wavePhase; // 0.0 → 1.0, avance chaque frame

  const WavePainter({required this.wavePhase});

  static const double _offset2 = 400 / 2000;
  static const double _offset3 = 800 / 2000;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    _drawEllipse(canvas, center, wavePhase, 0.04, 105, 98);
    _drawEllipse(
        canvas, center, (wavePhase + _offset2) % 1.0, 0.06, 90, 84);
    _drawEllipse(
        canvas, center, (wavePhase + _offset3) % 1.0, 0.08, 75, 70);
  }

  void _drawEllipse(Canvas canvas, Offset center, double phase,
      double opacity, double baseRx, double baseRy) {
    final scale = 1.0 + 0.05 * math.sin(2 * math.pi * phase);
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: baseRx * 2 * scale,
        height: baseRy * 2 * scale,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(WavePainter old) => old.wavePhase != wavePhase;
}
