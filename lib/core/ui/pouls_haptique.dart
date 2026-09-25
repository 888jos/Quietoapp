import 'package:flutter/services.dart' show HapticFeedback;

/// Le « pouls » d'une montée vers 100 % (compteur de l'onboarding, chargement
/// du programme, analyse Santé) : des impulsions de plus en plus rapprochées
/// et de plus en plus fortes à mesure qu'on approche de la fin, puis un coup
/// franc à l'arrivée (demande de Paul, 12/09).
///
/// À appeler à chaque image avec la progression 0 → 1 : la classe décide
/// seule quand vibrer, et avec quelle force. Le garde-fou de temps évite de
/// saturer le Taptic Engine (il avalerait les impulsions, et le rythme
/// paraîtrait haché).
class PoulsHaptique {
  double _derniere = -1; // dernière progression qui a vibré
  final Stopwatch _depuis = Stopwatch()..start();
  static const int _minEntreImpulsionsMs = 55;

  void avancer(double progression) {
    final p = progression.clamp(0.0, 1.0);
    // Le pas se resserre : tous les 4 % au début, tous les 1,5 % à la fin.
    final pas = p < 0.35
        ? 0.04
        : p < 0.65
            ? 0.03
            : p < 0.9
                ? 0.02
                : 0.015;
    if (_derniere >= 0 && p - _derniere < pas) return;
    if (_depuis.elapsedMilliseconds < _minEntreImpulsionsMs) return;
    _derniere = p;
    _depuis.reset();
    if (p < 0.35) {
      HapticFeedback.selectionClick();
    } else if (p < 0.65) {
      HapticFeedback.lightImpact();
    } else if (p < 0.9) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// L'arrivée à 100 % : le coup qui « pose » la fin.
  static void arrivee() => HapticFeedback.heavyImpact();
}
