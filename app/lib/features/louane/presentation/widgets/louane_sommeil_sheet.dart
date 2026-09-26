import 'dart:async';
import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/heure_paris.dart';
import '../louane_palette.dart';

/// Fait glisser depuis le bas — doucement, jusqu'à la moitié de l'écran —
/// la feuille « Louane se repose » : elle dort (petits Z qui s'envolent),
/// avec le temps restant avant son retour à minuit, heure de Paris.
Future<void> montrerLouaneSommeil(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xB3050B14),
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 700),
      reverseDuration: const Duration(milliseconds: 420),
    ),
    builder: (context) => const _FeuilleSommeil(),
  );
}

class _FeuilleSommeil extends StatelessWidget {
  const _FeuilleSommeil();

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.sizeOf(context).height * 0.5;
    final basSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      height: hauteur,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1F38), AppColors.background],
        ),
      ),
      child: Stack(
        children: [
          // Ciel étoilé, très discret.
          const Positioned.fill(
            child: CustomPaint(painter: _EtoilesPainter()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, 12, 28, 16 + basSafe),
            child: Column(
              children: [
                // Poignée.
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                const _LouaneEndormie(size: 92),
                const Spacer(),
                Text(
                  'Louane se repose',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "On s'est beaucoup parlé aujourd'hui, et j'ai besoin de "
                  "souffler un peu 🌙 Je serai là demain, promis. Et si ça ne "
                  "va vraiment pas en attendant, le 3114 est là 24h/24, "
                  "gratuitement.",
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),
                const _CompteARebours(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: LouanePalette.accent,
                      foregroundColor: AppColors.background,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    child: Text(
                      'À demain 🤍',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.background,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Elle revient dans 5 h 32 » — recalculé régulièrement, cible : minuit à Paris.
class _CompteARebours extends StatefulWidget {
  const _CompteARebours();

  @override
  State<_CompteARebours> createState() => _CompteAReboursState();
}

class _CompteAReboursState extends State<_CompteARebours> {
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  String get _texte {
    final reste = dureeAvantMinuitParis();
    if (reste.inMinutes < 1) return "Elle revient dans moins d'une minute";
    if (reste.inHours < 1) return 'Elle revient dans ${reste.inMinutes} min';
    final h = reste.inHours;
    final m = reste.inMinutes % 60;
    return 'Elle revient dans $h h ${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: LouanePalette.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nightlight_round,
              size: 15, color: LouanePalette.accent),
          const SizedBox(width: 8),
          Text(
            _texte,
            style: AppTextStyles.caption.copyWith(
              color: LouanePalette.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Louane endormie : le visage aux yeux fermés, une respiration lente,
/// et trois petits « Z » qui s'envolent au-dessus d'elle.
class _LouaneEndormie extends StatefulWidget {
  final double size;

  const _LouaneEndormie({required this.size});

  @override
  State<_LouaneEndormie> createState() => _LouaneEndormieState();
}

class _LouaneEndormieState extends State<_LouaneEndormie>
    with TickerProviderStateMixin {
  late final AnimationController _souffle; // respiration lente
  late final AnimationController _z; // envol des Z

  @override
  void initState() {
    super.initState();
    _souffle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _z = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _souffle.dispose();
    _z.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    // De la place au-dessus et à droite pour laisser monter les Z.
    return SizedBox(
      width: s * 1.8,
      height: s * 1.55,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Halo STATIQUE (dégradé, sans flou) : une ombre floutée qui grossit
          // avec la respiration scintillait sur iOS — plus rien n'est animé ici.
          // Centré sur le visage ; ce qui dépasse en bas est rogné par le Stack.
          Positioned(
            bottom: -s * 0.225,
            child: Container(
              width: s * 1.45,
              height: s * 1.45,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    LouanePalette.accent.withValues(alpha: 0.13),
                    LouanePalette.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _souffle,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_souffle.value);
              return Transform.scale(scale: 1.0 + 0.025 * t, child: child);
            },
            child: Container(
              width: s,
              height: s,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF8BD8D0), Color(0xFF3FA8A1)],
                ),
              ),
              child: CustomPaint(
                size: Size.square(s),
                painter: _VisageEndormiPainter(),
              ),
            ),
          ),
          // Les Z, décalés dans le temps, qui montent en fondu.
          for (var i = 0; i < 3; i++)
            AnimatedBuilder(
              animation: _z,
              builder: (context, _) {
                final p = (_z.value + i / 3) % 1.0; // 0 → 1, en boucle
                final fondu = sin(p * pi); // apparaît puis s'efface
                return Positioned(
                  bottom: s * (0.72 + p * 0.65),
                  right: s * (0.42 - p * 0.30),
                  child: Transform.scale(
                    scale: 0.6 + p * 0.7,
                    child: Text(
                      'z',
                      style: TextStyle(
                        fontSize: s * 0.22,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: LouanePalette.accent
                            .withValues(alpha: fondu * 0.9),
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

/// Le visage de Louane, paupières closes (deux petits arcs) et sourire paisible.
class _VisageEndormiPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final trait = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;

    // Yeux fermés : deux paupières en douceur (arcs vers le bas).
    for (final cx in [0.38, 0.62]) {
      final rect = Rect.fromCircle(
        center: Offset(w * cx, h * 0.42),
        radius: w * 0.075,
      );
      canvas.drawArc(rect, pi * 0.15, pi * 0.7, false, trait);
    }

    // Sourire léger, apaisé.
    final rect = Rect.fromCircle(
      center: Offset(w * 0.5, h * 0.54),
      radius: w * 0.13,
    );
    canvas.drawArc(rect, pi * 0.25, pi * 0.5, false, trait);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quelques étoiles fixes, à peine visibles — le ciel de Quieto.
class _EtoilesPainter extends CustomPainter {
  const _EtoilesPainter();

  // Positions (fractions de largeur/hauteur) et tailles, choisies à la main.
  static const _etoiles = <(double, double, double)>[
    (0.08, 0.12, 1.1),
    (0.18, 0.30, 0.8),
    (0.27, 0.08, 1.3),
    (0.40, 0.22, 0.7),
    (0.55, 0.10, 1.0),
    (0.66, 0.26, 0.8),
    (0.76, 0.07, 1.2),
    (0.86, 0.18, 0.9),
    (0.93, 0.34, 0.7),
    (0.12, 0.52, 0.9),
    (0.88, 0.55, 1.0),
    (0.05, 0.78, 0.7),
    (0.95, 0.80, 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final blanche = Paint()..color = Colors.white.withValues(alpha: 0.28);
    final turquoise =
        Paint()..color = LouanePalette.accent.withValues(alpha: 0.35);
    for (var i = 0; i < _etoiles.length; i++) {
      final (fx, fy, r) = _etoiles[i];
      canvas.drawCircle(
        Offset(size.width * fx, size.height * fy),
        r,
        i % 4 == 0 ? turquoise : blanche,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
