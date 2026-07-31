import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_constants.dart';

/// Boutons de connexion aux couleurs officielles des marques, comme sur
/// toutes les apps : Apple en noir avec la pomme blanche, Google en blanc
/// avec le « G » multicolore. Seule la forme (arrondi, hauteur) suit le
/// style Quieto pour que la page reste cohérente.

class BoutonConnexionApple extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const BoutonConnexionApple({super.key, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return _BoutonMarque(
      onTap: onTap,
      isLoading: isLoading,
      background: Colors.black,
      foreground: Colors.white,
      label: 'Continuer avec Apple',
      // La pomme Material est décalée un poil vers le haut pour être
      // optiquement centrée face au texte, comme le bouton officiel.
      logo: const Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: Icon(Icons.apple, color: Colors.white, size: 24),
      ),
    );
  }
}

class BoutonConnexionGoogle extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;

  const BoutonConnexionGoogle({super.key, this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return _BoutonMarque(
      onTap: onTap,
      isLoading: isLoading,
      background: Colors.white,
      // Gris presque noir des boutons Google officiels.
      foreground: const Color(0xFF1F1F1F),
      label: 'Continuer avec Google',
      logo: const CustomPaint(
        size: Size.square(20),
        painter: _LogoGooglePainter(),
      ),
    );
  }
}

class _BoutonMarque extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final Color background;
  final Color foreground;
  final String label;
  final Widget logo;

  const _BoutonMarque({
    required this.onTap,
    required this.isLoading,
    required this.background,
    required this.foreground,
    required this.label,
    required this.logo,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null || isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: AppConstants.animFast),
      opacity: isDisabled ? 0.6 : 1.0,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: InkWell(
          onTap: isDisabled
              ? null
              : () {
                  onTap!();
                  scheduleMicrotask(() => HapticFeedback.mediumImpact());
                },
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          child: Container(
            height: 52,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  logo,
                const SizedBox(width: AppConstants.spacingSm + 2),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le « G » de Google, transcrit du logo vectoriel officiel (grille 48x48) :
/// les quatre quartiers bleu, vert, jaune et rouge, aux couleurs exactes.
class _LogoGooglePainter extends CustomPainter {
  const _LogoGooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 48;
    Offset o(double x, double y) => Offset(x * k, y * k);
    void c(Path p, Offset c1, Offset c2, Offset end) =>
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    // Bleu : la barre horizontale et le flanc droit.
    final bleu = Path()..moveTo(o(45.12, 24.5).dx, o(45.12, 24.5).dy);
    c(bleu, o(45.12, 22.94), o(44.98, 21.44), o(44.72, 20.0));
    bleu
      ..lineTo(o(24, 20.0).dx, o(24, 20.0).dy)
      ..lineTo(o(24, 28.51).dx, o(24, 28.51).dy)
      ..lineTo(o(35.84, 28.51).dx, o(35.84, 28.51).dy);
    c(bleu, o(35.33, 31.26), o(33.78, 33.59), o(31.45, 35.15));
    bleu
      ..lineTo(o(31.45, 40.67).dx, o(31.45, 40.67).dy)
      ..lineTo(o(38.56, 40.67).dx, o(38.56, 40.67).dy);
    c(bleu, o(42.72, 36.84), o(45.12, 31.2), o(45.12, 24.5));
    bleu.close();
    canvas.drawPath(bleu, Paint()..color = const Color(0xFF4285F4));

    // Vert : le bas.
    final vert = Path()..moveTo(o(24, 46).dx, o(24, 46).dy);
    c(vert, o(29.94, 46), o(34.92, 44.03), o(38.56, 40.67));
    vert.lineTo(o(31.45, 35.15).dx, o(31.45, 35.15).dy);
    c(vert, o(29.48, 36.47), o(26.96, 37.25), o(24, 37.25));
    c(vert, o(18.27, 37.25), o(13.42, 33.38), o(11.69, 28.18));
    vert
      ..lineTo(o(4.34, 28.18).dx, o(4.34, 28.18).dy)
      ..lineTo(o(4.34, 33.88).dx, o(4.34, 33.88).dy);
    c(vert, o(7.96, 41.07), o(15.4, 46), o(24, 46));
    vert.close();
    canvas.drawPath(vert, Paint()..color = const Color(0xFF34A853));

    // Jaune : le flanc gauche.
    final jaune = Path()..moveTo(o(11.69, 28.18).dx, o(11.69, 28.18).dy);
    c(jaune, o(11.25, 26.86), o(11, 25.45), o(11, 24));
    c(jaune, o(11, 22.55), o(11.25, 21.14), o(11.69, 19.82));
    jaune
      ..lineTo(o(11.69, 14.12).dx, o(11.69, 14.12).dy)
      ..lineTo(o(4.34, 14.12).dx, o(4.34, 14.12).dy);
    c(jaune, o(2.85, 17.09), o(2, 20.45), o(2, 24));
    c(jaune, o(2, 27.55), o(2.85, 30.91), o(4.34, 33.88));
    jaune.lineTo(o(11.69, 28.18).dx, o(11.69, 28.18).dy);
    jaune.close();
    canvas.drawPath(jaune, Paint()..color = const Color(0xFFFBBC05));

    // Rouge : le haut.
    final rouge = Path()..moveTo(o(24, 10.75).dx, o(24, 10.75).dy);
    c(rouge, o(27.23, 10.75), o(30.13, 11.86), o(32.41, 14.04));
    rouge.lineTo(o(38.72, 7.73).dx, o(38.72, 7.73).dy);
    c(rouge, o(34.91, 4.18), o(29.93, 2), o(24, 2));
    c(rouge, o(15.4, 2), o(7.96, 6.93), o(4.34, 12.12));
    rouge.lineTo(o(11.69, 17.82).dx, o(11.69, 17.82).dy);
    c(rouge, o(13.42, 12.62), o(18.27, 8.75), o(24, 10.75));
    rouge.close();
    canvas.drawPath(rouge, Paint()..color = const Color(0xFFEA4335));
  }

  @override
  bool shouldRepaint(_LogoGooglePainter oldDelegate) => false;
}
