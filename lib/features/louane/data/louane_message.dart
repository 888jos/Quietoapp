/// Un message dans la conversation avec Louane.
enum AuteurMessage { user, louane }

class LouaneMessage {
  final AuteurMessage auteur;
  final String texte;

  /// Bulle de fin des 15 messages découverte : la page affiche dessous le
  /// bouton « Commencer mon essai gratuit » (ouvre l'écran d'abonnement).
  final bool avecBoutonEssai;

  const LouaneMessage({
    required this.auteur,
    required this.texte,
    this.avecBoutonEssai = false,
  });

  bool get estLouane => auteur == AuteurMessage.louane;
}
