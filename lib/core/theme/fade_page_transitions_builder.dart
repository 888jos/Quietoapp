import 'package:flutter/material.dart';

/// Transition d'écran par défaut : fondu respirant (opacité + micro zoom),
/// identique au langage de transitions du routeur (QuietoTransitions).
/// Sert de filet pour toute page poussée hors du routeur.
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
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final receding = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.7).animate(receding),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.97).animate(receding),
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.0).animate(curved),
            child: RepaintBoundary(child: child),
          ),
        ),
      ),
    );
  }
}
