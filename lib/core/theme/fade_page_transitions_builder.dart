import 'package:flutter/material.dart';

/// Transition d'écran personnalisée : fade-in/out doux, sans slide horizontal
/// ni effet "page qui tourne". Plus cohérent avec l'esprit calme de Quieto.
///
/// Appliqué globalement via [PageTransitionsTheme] dans [AppTheme.dark].
class FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }
}
