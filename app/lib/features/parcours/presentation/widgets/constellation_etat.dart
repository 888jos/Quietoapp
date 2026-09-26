import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../../core/models/parcours_model.dart';
import '../../../../core/theme/app_colors.dart';
import 'constellation_reveal.dart';

// ── Le hero : la constellation de la semaine, version état ──
// Les étoiles des jours faits brillent, celle du jour courant pulse
// doucement, les suivantes attendent, éteintes. Même géométrie que la
// révélation de l'écran de création. Sert aussi à la carte de partage
// (painter réutilisé tel quel, animations à l'arrêt).

class ConstellationEtat extends StatefulWidget {
  final ParcoursModel parcours;

  /// Jour dont l'étoile vient d'être gagnée : elle s'allume en direct
  /// (flambée + trait qui avance vers le jour suivant + vibration), une
  /// seule fois. Au jour 7, toute la constellation scintille ensuite.
  final int? jourNouveau;

  const ConstellationEtat({super.key, required this.parcours, this.jourNouveau});

  @override
  State<ConstellationEtat> createState() => _ConstellationEtatState();
}

class _ConstellationEtatState extends State<ConstellationEtat>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  late final AnimationController _allumage = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
    value: 1, // au repos = rendu statique
  );

  late final AnimationController _scintillement = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// Allumage demandé mais pas encore joué : on attend que la page soit
  /// réellement visible (au retour du player, pas en dessous).
  bool _celebrationEnAttente = false;

  @override
  void initState() {
    super.initState();
    _allumage.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      if (widget.jourNouveau == 7 && !_scintillement.isAnimating) {
        HapticFeedback.lightImpact();
        _scintillement.forward(from: 0);
      }
    });
    _celebrationEnAttente = widget.jourNouveau != null;
  }

  @override
  void didUpdateWidget(ConstellationEtat old) {
    super.didUpdateWidget(old);
    if (widget.jourNouveau != null && widget.jourNouveau != old.jourNouveau) {
      _celebrationEnAttente = true;
      _essayerAllumage();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Les tickers d'une page recouverte sont en pause, mais leur horloge
    // tourne quand même : lancée trop tôt, l'animation arriverait déjà
    // finie. On ne démarre donc qu'une fois la constellation visible
    // (TickerMode repasse à vrai quand le player se ferme).
    _essayerAllumage();
  }

  void _essayerAllumage() {
    if (!_celebrationEnAttente || !TickerMode.valuesOf(context).enabled) {
      return;
    }
    _celebrationEnAttente = false;
    HapticFeedback.mediumImpact();
    _allumage.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _allumage.dispose();
    _scintillement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: ConstellationEtatPainter(
          pulse: CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
          faits: {
            for (final j in widget.parcours.jours)
              if (widget.parcours.jourTermine(j.jour)) j.jour,
          },
          jourCourant: widget.parcours.tousJoursTermines
              ? 0
              : widget.parcours.jourCourant,
          jourNouveau: widget.jourNouveau,
          allumage: _allumage,
          scintillement: _scintillement,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class ConstellationEtatPainter extends CustomPainter {
  ConstellationEtatPainter({
    required this.pulse,
    required this.faits,
    required this.jourCourant,
    this.jourNouveau,
    this.allumage = const AlwaysStoppedAnimation(1),
    this.scintillement = const AlwaysStoppedAnimation(0),
  }) : super(repaint: Listenable.merge([pulse, allumage, scintillement]));

  final Animation<double> pulse;
  final Set<int> faits;
  final int jourCourant; // 0 = plus de jour courant (semaine finie)
  final int? jourNouveau;
  final Animation<double> allumage; // 1 au repos (rendu statique)
  final Animation<double> scintillement; // 0 au repos

  // LA même géométrie que la constellation voyageuse (révélation) : quand
  // elle se pose sur le hero, chaque étoile tombe pile sur son double.
  Offset _pos(int i, Size size) => positionEtoileConstellation(i, size);

  @override
  void paint(Canvas canvas, Size size) {
    final t = allumage.value;
    final enAllumage = jourNouveau != null && t < 1;
    // Le scintillement du jour 7 : une respiration douce et synchronisée
    // de toute la constellation, une seule fois.
    final brillance = math.sin(math.pi * scintillement.value);

    // Les traits : allumés jusqu'au dernier jour fait, éteints ensuite.
    for (var i = 0; i < 6; i++) {
      final a = _pos(i, size);
      final b = _pos(i + 1, size);
      // Pendant l'allumage, le trait vers le jour suivant se dessine en
      // direct au lieu d'apparaître déjà fini.
      if (enAllumage && i == jourNouveau! - 1) {
        final part = ((t - 0.31) / 0.69).clamp(0.0, 1.0);
        if (part > 0) {
          canvas.drawLine(
            a,
            Offset.lerp(a, b, part)!,
            Paint()
              ..color = AppColors.accent.withValues(alpha: 0.45)
              ..strokeWidth = 1.3
              ..strokeCap = StrokeCap.round,
          );
        }
        continue;
      }
      final marche = faits.contains(i + 2) ||
          (i + 2 == jourCourant && faits.contains(i + 1));
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = marche
              ? AppColors.accent.withValues(alpha: 0.45 + 0.20 * brillance)
              : Colors.white.withValues(alpha: 0.10)
          ..strokeWidth = marche ? 1.3 : 1.0
          ..strokeCap = StrokeCap.round,
      );
    }

    for (var i = 1; i <= 7; i++) {
      final pos = _pos(i - 1, size);
      final fait = faits.contains(i);
      final courant = i == jourCourant;
      final double alphaLabel;

      if (enAllumage && i == jourNouveau) {
        // L'ignition : la flambée gonfle puis l'étoile se pose exactement
        // sur son rendu « fait » (aucun saut à la fin).
        final local = (t / 0.5).clamp(0.0, 1.0);
        final flambee = math.sin(math.pi * local);
        canvas.drawCircle(
          pos,
          7 + 9 * flambee,
          Paint()
            ..color = AppColors.accent.withValues(alpha: 0.35 + 0.35 * flambee)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
          pos,
          2.6 + 1.0 * flambee,
          Paint()..color = Colors.white.withValues(alpha: 0.95),
        );
        alphaLabel = 0.9;
      } else if (fait) {
        canvas.drawCircle(
          pos,
          7 + 2 * brillance,
          Paint()
            ..color =
                AppColors.accent.withValues(alpha: 0.35 + 0.20 * brillance)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
            pos, 2.6, Paint()..color = Colors.white.withValues(alpha: 0.95));
        alphaLabel = 0.8;
      } else if (courant) {
        final p = pulse.value;
        canvas.drawCircle(
          pos,
          8 + 4 * p,
          Paint()
            ..color = AppColors.accent.withValues(alpha: 0.25 + 0.30 * p)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(
            pos, 3.0, Paint()..color = Colors.white.withValues(alpha: 0.95));
        alphaLabel = 0.9;
      } else {
        canvas.drawCircle(
            pos, 2.2, Paint()..color = Colors.white.withValues(alpha: 0.20));
        alphaLabel = 0.35;
      }

      peindreLabelJour(canvas, pos, i, alphaLabel);
    }
  }

  @override
  bool shouldRepaint(ConstellationEtatPainter old) =>
      old.faits.length != faits.length ||
      old.jourCourant != jourCourant ||
      old.jourNouveau != jourNouveau;
}
