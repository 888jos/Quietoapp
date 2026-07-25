/// Un message dans la conversation avec Louane.
enum AuteurMessage { user, louane }

class LouaneMessage {
  final AuteurMessage auteur;
  final String texte;

  /// Bulle de fin des messages découverte : la page affiche dessous le
  /// bouton « Commencer mon essai gratuit » (ouvre l'écran d'abonnement).
  final bool avecBoutonEssai;

  /// Séance que Louane lance dans la conversation (marqueur [SEANCE:id]
  /// validé côté serveur) : la page affiche sous la bulle la carte qui
  /// démarre la séance. Null = message ordinaire.
  final String? seanceId;

  /// Louane propose de créer le programme de 7 jours (marqueur [PARCOURS]
  /// strippé côté serveur) : la page affiche sous la bulle le bouton
  /// « Crée-moi mon programme » (masqué dès qu'un programme existe).
  final bool avecBoutonParcours;

  const LouaneMessage({
    required this.auteur,
    required this.texte,
    this.avecBoutonEssai = false,
    this.seanceId,
    this.avecBoutonParcours = false,
  });

  bool get estLouane => auteur == AuteurMessage.louane;
}
