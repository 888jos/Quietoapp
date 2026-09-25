import '../../../core/services/health_service.dart' show AnalyseSante;

/// Un message dans la conversation avec Louane. [systeme] = fine ligne
/// d'information centrée dans le fil (ex. « Essai Premium activé »), jamais
/// envoyée au serveur : ce n'est pas Louane qui parle.
enum AuteurMessage { user, louane, systeme }

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

  /// Bulle d'ouverture du programme (« ton programme t'attend sur
  /// l'accueil »), glissée dans le fil à la création. Une seule à la fois :
  /// recréer un programme remplace la précédente au lieu de l'empiler.
  final bool estOuvertureParcours;

  /// Carte « Louane analyse ton questionnaire Santé » (marqueur [ANALYSE]
  /// posé par le serveur) : pas une bulle, [texte] vide, jamais envoyée au
  /// serveur telle quelle. Porte le test et ses réponses (ce que la carte
  /// fait défiler) et sa durée. [analyseDebut] = l'instant où la carte est
  /// apparue : son animation se déduit de l'heure, jamais rejouée.
  final AnalyseSante? analyse;
  final DateTime? analyseDebut;

  /// Première bulle qui suit la carte d'analyse : réinjectée dans
  /// l'historique API avec le marqueur [ANALYSE] devant, pour que Louane
  /// sache qu'elle a déjà fait ce moment-là (et ne le refasse pas).
  final bool porteAnalyse;

  /// Quand le message est entré dans le fil (posée par le chat, jamais par
  /// l'appelant) : l'en-tête du menu contextuel l'affiche (22/09/2026).
  final DateTime? date;

  const LouaneMessage({
    required this.auteur,
    required this.texte,
    this.avecBoutonEssai = false,
    this.seanceId,
    this.avecBoutonParcours = false,
    this.estOuvertureParcours = false,
    this.analyse,
    this.analyseDebut,
    this.porteAnalyse = false,
    this.date,
  });

  LouaneMessage avecDate(DateTime d) => LouaneMessage(
        auteur: auteur,
        texte: texte,
        avecBoutonEssai: avecBoutonEssai,
        seanceId: seanceId,
        avecBoutonParcours: avecBoutonParcours,
        estOuvertureParcours: estOuvertureParcours,
        analyse: analyse,
        analyseDebut: analyseDebut,
        porteAnalyse: porteAnalyse,
        date: d,
      );

  bool get estLouane => auteur == AuteurMessage.louane;

  bool get estCarteAnalyse => analyse != null;
}
