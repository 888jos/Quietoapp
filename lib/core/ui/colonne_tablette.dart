import 'package:flutter/material.dart';

/// iPad (portrait uniquement, comme l'iPhone) : l'app garde EXACTEMENT sa
/// mise en page téléphone, mais mise à l'échelle pour remplir la tablette.
/// Textes, boutons, cartes, marges, fonds… tout grossit du même facteur :
/// les boutons deviennent bien plus larges sans jamais s'étirer jusqu'aux
/// bords (ils gardent leurs marges, agrandies elles aussi).
///
/// Principe : l'écran est traité comme un téléphone de [largeurLogique]
/// points de large, puis peint avec un zoom `largeur réelle / largeurLogique`
/// (×1,7 sur l'iPad Pro 13", ×1,4 sur le 11", ×1,25 sur le mini).
abstract final class Tablette {
  /// Largeur logique que « voit » l'app sur iPad. Plus elle est petite,
  /// plus tout est gros. Sur téléphone (≤ cette largeur) : aucun zoom.
  static const largeurLogique = 600.0;

  /// Vrai sur iPad — pour les quelques réglages qui ne sont pas de la mise
  /// en page (hauteur de couverture, « ton iPhone » / « ton iPad »…).
  static bool estTablette(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_EchelleHeritee>()?.echelle !=
      null;
}

/// À poser UNE fois, dans le `builder` de `MaterialApp.router` : englobe
/// le Navigator, donc aussi les dialogues, bottom sheets et snackbars.
/// Sur téléphone, rend l'enfant tel quel.
class EchelleTablette extends StatelessWidget {
  final Widget child;

  const EchelleTablette({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth;
        final hauteur = contraintes.maxHeight;
        if (!largeur.isFinite ||
            !hauteur.isFinite ||
            largeur <= Tablette.largeurLogique) {
          return child;
        }
        final echelle = largeur / Tablette.largeurLogique;
        final taille = Size(Tablette.largeurLogique, hauteur / echelle);
        final mq = MediaQuery.of(context);
        return _EchelleHeritee(
          echelle: echelle,
          child: MediaQuery(
            // L'app se croit sur un écran de [taille] : les zones sûres et
            // le clavier sont ramenés à cette échelle (une fois zoomés, ils
            // retombent au pixel près sur les vraies barres du système).
            data: mq.copyWith(
              size: taille,
              padding: mq.padding / echelle,
              viewPadding: mq.viewPadding / echelle,
              viewInsets: mq.viewInsets / echelle,
              systemGestureInsets: mq.systemGestureInsets / echelle,
              devicePixelRatio: mq.devicePixelRatio * echelle,
            ),
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: taille.width,
              maxWidth: taille.width,
              minHeight: taille.height,
              maxHeight: taille.height,
              child: Transform.scale(
                scale: echelle,
                alignment: Alignment.topLeft,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EchelleHeritee extends InheritedWidget {
  final double echelle;

  const _EchelleHeritee({required this.echelle, required super.child});

  @override
  bool updateShouldNotify(_EchelleHeritee old) => old.echelle != echelle;
}
