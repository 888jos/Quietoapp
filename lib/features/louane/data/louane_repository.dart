import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/models/parcours_model.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/vigie_service.dart';
import 'heure_paris.dart';

/// Le jour local en toutes lettres (ex. « vendredi 18 juillet »), envoyé au
/// serveur. Publique pour le test.
String jourLocalEnFrancais(DateTime d) {
  const jours = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];
  const mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet',
    'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];
  return '${jours[d.weekday - 1]} ${d.day} ${mois[d.month - 1]}';
}

/// Ce que le serveur a répondu. Soit un texte de Louane, soit un signal de
/// limite : [paywall] = les messages découverte sont épuisés (non-abonné),
/// [plafond] = les 40 messages du jour sont atteints (abonné) → Louane dort.
class LouaneReponse {
  final String texte;
  final bool paywall;
  final bool plafond;

  /// Id de la séance que Louane lance dans la conversation (déjà validé
  /// contre le catalogue côté serveur). Null = pas de lancement.
  final String? seanceId;

  /// Louane vient de proposer de créer le programme de 7 jours (marqueur
  /// [PARCOURS] strippé côté serveur) → l'app affiche le bouton dessous.
  final bool parcoursPropose;

  /// Dernier message découverte : Louane vient de faire son au revoir →
  /// le bouton « essai gratuit » s'affiche directement sous cette bulle.
  final bool finDecouverte;

  const LouaneReponse({
    this.texte = '',
    this.paywall = false,
    this.plafond = false,
    this.seanceId,
    this.parcoursPropose = false,
    this.finDecouverte = false,
  });
}

/// Appelle la Cloud Function "louane" (le serveur) et renvoie sa réponse.
/// Gère aussi la MÉMOIRE locale : on envoie ce que Louane sait déjà (stocké sur
/// le téléphone) et on sauvegarde la fiche mise à jour qu'elle renvoie.
/// Et les QUOTAS : compteurs locaux (jamais affichés), envoyés au serveur qui
/// décide seul des limites — le Veilleur, lui, tourne même quota épuisé.
class LouaneRepository {
  LouaneRepository(this._storage, this._vigie, this._abonne);

  final StorageService _storage;
  final VigieService _vigie;

  /// Lu au moment de CHAQUE envoi (pas figé à la construction) : si la
  /// personne s'abonne en pleine conversation, le message suivant part
  /// déjà avec le bon statut, sans réinitialiser le fil.
  final bool Function() _abonne;

  Future<LouaneReponse> envoyer(
    String message,
    List<Map<String, String>> historique, {
    String accueil = '',
  }) async {
    // Heure locale du téléphone (ex. "23:47") → Louane salue au bon moment.
    final maintenant = DateTime.now();
    final heure = '${maintenant.hour.toString().padLeft(2, '0')}:'
        '${maintenant.minute.toString().padLeft(2, '0')}';

    // Le quota du jour est rattaché à la date à PARIS : à minuit heure
    // française, louaneCompteurJour repart de zéro tout seul.
    final jour = cleJourParis();

    final callable = FirebaseFunctions.instance.httpsCallable('louane');
    // Vigie : temps de réponse VÉCU par la personne (départ du message →
    // réponse affichable). Si Louane devient lente, c'est ici qu'on le voit.
    final chrono = Stopwatch()..start();
    final result = await callable.call(<String, dynamic>{
      'message': message,
      'historique': historique,
      'heure': heure,
      // Le jour en toutes lettres → Louane ne se trompe plus de jour de la
      // semaine (elle le devinait, et se plantait).
      'jour': jourLocalEnFrancais(maintenant),
      // Les bulles d'accueil en dur (absentes de l'historique API) → Louane
      // sait ce qu'elle vient de dire et ne répond pas à côté.
      'accueil': accueil,
      'prenom': _storage.firstName,
      'memoire': _storage.louaneMemoire,
      // Réponses d'onboarding (objectifs, expérience, moment, durée) →
      // Louane adapte son accompagnement et ses suggestions de séances.
      'profil': _storage.getOnboardingAnswers(),
      // Résumé des évaluations bien-être d'Apple Santé (niveau grossier,
      // jamais le score). Cache mémoire → lecture synchrone, jamais bloquant.
      'sante': HealthService.instance.resumeSanteCache,
      // Appareil compatible Apple Santé (iPhone) → Louane sait ce qui est
      // possible ici (minutes dans Santé, questionnaires) et n'en parle
      // jamais sur Android.
      'santeDispo': HealthService.instance.disponible,
      'abonne': _abonne(),
      // Résumé d'écoutes {id, fois, jours} → Louane varie ses suggestions
      // et peut reproposer une séance qui a plu.
      'ecoutes': _storage.ecoutesPourLouane(),
      // État du programme 7 jours (null si aucun) → Louane suit la
      // progression (check-in) et ne re-propose jamais un programme en cours.
      'parcours': _storage
          .loadParcours()
          ?.pourServeur(ParcoursModel.cleJourLocal(maintenant)),
      'compteurTotal': _storage.louaneCompteurTotal,
      'compteurJour': _storage.louaneCompteurJour(jour),
      // Vigie : IDs anonymes → le serveur relie ses stats de conversation
      // (sujets, émotion — jamais le texte) au parcours dans l'app.
      'vigie': _vigie.id,
      'session': _vigie.session,
    });
    chrono.stop();
    final data = result.data as Map;
    _vigie.log('louane_reponse', {
      'ms': chrono.elapsedMilliseconds,
      'paywall': data['paywall'] == true,
      'plafond': data['plafond'] == true,
    });

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

    // Signal de lancement de séance : on ne garde que l'id (l'app retrouve
    // titre, durée et image dans son propre catalogue).
    final seance = data['seance'];
    final seanceId = (seance is Map) ? (seance['id'] as String?)?.trim() : null;

    return LouaneReponse(
      texte: (data['reponse'] as String?)?.trim() ?? '',
      paywall: paywall,
      plafond: plafond,
      seanceId: (seanceId != null && seanceId.isNotEmpty) ? seanceId : null,
      parcoursPropose: data['parcoursPropose'] == true,
      finDecouverte: data['finDecouverte'] == true,
    );
  }
}
