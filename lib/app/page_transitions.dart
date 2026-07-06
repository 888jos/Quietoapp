import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Langage de transitions Quieto : 3 mouvements, pas un de plus.
///
///  - [fadePage]  : fondu respirant. Changement d'étape ou de contexte
///                  (splash, onboarding, paywall en fin d'onboarding).
///  - [slidePage] : glissée latérale douce. On "entre" dans un contenu
///                  (préparation de séance).
///  - [sheetPage] : montée depuis le bas. Moment immersif ou modal
///                  (catégorie, lecteur, paywall depuis une séance premium).
///
/// Dans les 3 cas, la page qui reste dessous recule légèrement et
/// s'estompe : ça donne la sensation de profondeur, sans brusquerie.
abstract final class QuietoTransitions {
  static const Duration forward = Duration(milliseconds: 400);
  static const Duration back = Duration(milliseconds: 320);

  /// Durée du fondu croisé entre les onglets de la barre du bas.
  static const Duration tabSwitch = Duration(milliseconds: 300);

  static CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  /// La page dessous recule un peu (échelle 0.97) et s'estompe pendant
  /// qu'une autre page la recouvre.
  static Widget _receding(Animation<double> secondary, Widget child) {
    final curved = _curve(secondary);
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.7).animate(curved),
      child: ScaleTransition(
        scale: Tween(begin: 1.0, end: 0.97).animate(curved),
        child: child,
      ),
    );
  }

  /// Fige la page en une image mise en cache pendant l'animation :
  /// le téléphone déplace / estompe cette image au lieu de redessiner
  /// toute la page à chaque frame. C'est la clé de la fluidité.
  static Widget _cached(Widget page) => RepaintBoundary(child: page);

  /// Fondu respirant : opacité + micro zoom (0.98 → 1).
  static CustomTransitionPage<void> fadePage({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: forward,
      reverseTransitionDuration: back,
      transitionsBuilder: (context, animation, secondary, page) {
        final curved = _curve(animation);
        return _receding(
          secondary,
          FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.98, end: 1.0).animate(curved),
              child: _cached(page),
            ),
          ),
        );
      },
    );
  }

  /// Glissée latérale douce : arrive de la droite (25 % de l'écran) en fondu.
  static CustomTransitionPage<void> slidePage({
    required LocalKey key,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: forward,
      reverseTransitionDuration: back,
      transitionsBuilder: (context, animation, secondary, page) {
        final curved = _curve(animation);
        return _receding(
          secondary,
          SlideTransition(
            position: Tween(
              begin: const Offset(0.25, 0),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(opacity: curved, child: _cached(page)),
          ),
        );
      },
    );
  }

  /// Montée depuis le bas, façon feuille modale.
  ///
  /// [fadeBack] : au retour, la page s'efface sur place en fondu croisé
  /// (comme le changement d'onglet) au lieu de redescendre.
  static CustomTransitionPage<void> sheetPage({
    required LocalKey key,
    required Widget child,
    bool fadeBack = false,
  }) {
    return CustomTransitionPage<void>(
      key: key,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: back,
      transitionsBuilder: (context, animation, secondary, page) {
        final curved = _curve(animation);
        final cached = _cached(page);
        if (!fadeBack) {
          return _receding(
            secondary,
            SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curved),
              child: FadeTransition(opacity: curved, child: cached),
            ),
          );
        }
        return _receding(
          secondary,
          AnimatedBuilder(
            animation: animation,
            child: cached,
            builder: (context, child) {
              final exiting = animation.status == AnimationStatus.reverse;
              return FractionalTranslation(
                translation: exiting
                    ? Offset.zero
                    : Offset(0, 1 - curved.value),
                child: Opacity(opacity: curved.value, child: child),
              );
            },
          ),
        );
      },
    );
  }
}

/// Fondu croisé entre les onglets de la barre du bas.
///
/// Remplace la coupure sèche de l'IndexedStack : l'onglet sortant
/// s'estompe pendant que l'entrant apparaît avec un micro zoom.
/// L'état de chaque onglet (scroll, saisie…) est conservé.
class AnimatedBranchContainer extends StatelessWidget {
  final int currentIndex;
  final List<Widget> children;

  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Le fondu (AnimatedOpacity / AnimatedScale) doit rester EN DEHORS
        // du TickerMode : sinon, couper les animations de l'onglet sortant
        // gèle aussi son fondu de sortie, et il reste affiché par-dessus
        // les autres (écran "bloqué").
        for (var i = 0; i < children.length; i++)
          AnimatedOpacity(
            opacity: i == currentIndex ? 1.0 : 0.0,
            duration: QuietoTransitions.tabSwitch,
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: i == currentIndex ? 1.0 : 0.98,
              duration: QuietoTransitions.tabSwitch,
              curve: Curves.easeOutCubic,
              child: IgnorePointer(
                ignoring: i != currentIndex,
                child: TickerMode(
                  enabled: i == currentIndex,
                  child: RepaintBoundary(child: children[i]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
