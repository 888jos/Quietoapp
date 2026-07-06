import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/services/storage_service.dart';
import 'heure_paris.dart';

/// Ce que le serveur a répondu. Soit un texte de Louane, soit un signal de
/// limite : [paywall] = les 15 messages découverte sont épuisés (non-abonné),
/// [plafond] = les 40 messages du jour sont atteints (abonné) → Louane dort.
class LouaneReponse {
  final String texte;
  final bool paywall;
  final bool plafond;

  const LouaneReponse({
    this.texte = '',
    this.paywall = false,
    this.plafond = false,
  });
}

/// Appelle la Cloud Function "louane" (le serveur) et renvoie sa réponse.
/// Gère aussi la MÉMOIRE locale : on envoie ce que Louane sait déjà (stocké sur
/// le téléphone) et on sauvegarde la fiche mise à jour qu'elle renvoie.
/// Et les QUOTAS : compteurs locaux (jamais affichés), envoyés au serveur qui
/// décide seul des limites — le Veilleur, lui, tourne même quota épuisé.
class LouaneRepository {
  LouaneRepository(this._storage, this._abonne);

  final StorageService _storage;

  /// Lu au moment de CHAQUE envoi (pas figé à la construction) : si la
  /// personne s'abonne en pleine conversation, le message suivant part
  /// déjà avec le bon statut, sans réinitialiser le fil.
  final bool Function() _abonne;

  Future<LouaneReponse> envoyer(
    String message,
    List<Map<String, String>> historique,
  ) async {
    // Heure locale du téléphone (ex. "23:47") → Louane salue au bon moment.
    final maintenant = DateTime.now();
    final heure = '${maintenant.hour.toString().padLeft(2, '0')}:'
        '${maintenant.minute.toString().padLeft(2, '0')}';

    // Le quota du jour est rattaché à la date à PARIS : à minuit heure
    // française, louaneCompteurJour repart de zéro tout seul.
    final jour = cleJourParis();

    final callable = FirebaseFunctions.instance.httpsCallable('louane');
    final result = await callable.call(<String, dynamic>{
      'message': message,
      'historique': historique,
      'heure': heure,
      'prenom': _storage.firstName,
      'memoire': _storage.louaneMemoire,
      // Réponses d'onboarding (objectifs, expérience, moment, durée) →
      // Louane adapte son accompagnement et ses suggestions de séances.
      'profil': _storage.getOnboardingAnswers(),
      'abonne': _abonne(),
      'compteurTotal': _storage.louaneCompteurTotal,
      'compteurJour': _storage.louaneCompteurJour(jour),
    });
    final data = result.data as Map;

    // Le serveur renvoie la fiche mémoire mise à jour → on la garde sur le tél.
    final nouvelleMemoire = (data['memoire'] as String?)?.trim();
    if (nouvelleMemoire != null &&
        nouvelleMemoire != _storage.louaneMemoire) {
      await _storage.setLouaneMemoire(nouvelleMemoire);
    }

    final paywall = data['paywall'] == true;
    final plafond = data['plafond'] == true;

    // Un message n'est décompté que si Louane a vraiment répondu.
    if (!paywall && !plafond) {
      await _storage.incrementeLouaneCompteurs(jour);
    }

    return LouaneReponse(
      texte: (data['reponse'] as String?)?.trim() ?? '',
      paywall: paywall,
      plafond: plafond,
    );
  }
}
