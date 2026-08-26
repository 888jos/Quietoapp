import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/models/parcours_model.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/vigie_service.dart';

/// Ce que la génération renvoie : le programme (à persister) + la bulle
/// d'ouverture de Louane (à glisser dans le fil de conversation, une fois).
class ParcoursGenere {
  final ParcoursModel parcours;
  final String messageOuverture;
  final bool fallback;

  const ParcoursGenere({
    required this.parcours,
    required this.messageOuverture,
    required this.fallback,
  });
}

/// Appelle la Cloud Function "genererParcours" : Louane compose le programme
/// de 7 jours à partir de la conversation (historique passé par l'appelant),
/// de sa fiche mémoire et du profil d'onboarding. Stateless comme "louane" :
/// c'est l'app qui persiste le programme reçu.
class ParcoursRepository {
  ParcoursRepository(this._storage, this._vigie, this._abonne);

  final StorageService _storage;
  final VigieService _vigie;
  final bool Function() _abonne;

  Future<ParcoursGenere> generer(
      List<Map<String, String>> historique) async {
    // La génération est un « moment » (écran d'attente animé) : on laisse au
    // serveur le temps d'un retry interne avant de déclarer l'échec.
    final callable = FirebaseFunctions.instance.httpsCallable(
      'genererParcours',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final chrono = Stopwatch()..start();
    final result = await callable.call(<String, dynamic>{
      'historique': historique,
      'memoire': _storage.louaneMemoire,
      'profil': _storage.getOnboardingAnswers(),
      // Résumé des évaluations bien-être d'Apple Santé (niveau grossier,
      // jamais le score) → le programme se dose en douceur si besoin.
      'sante': HealthService.instance.resumeSanteCache,
      // Résumé d'écoutes {id, fois, jours} → le programme s'appuie sur ce
      // qu'elle connaît déjà sans remplir la semaine de séances usées.
      'ecoutes': _storage.ecoutesPourLouane(),
      'prenom': _storage.firstName,
      'abonne': _abonne(),
      // Tout premier programme → le backend force le jour 1 à
      // « Ma première méditation » (quasi personne n'a jamais médité).
      'premierParcours': !_storage.parcoursDejaCree,
      'vigie': _vigie.id,
      'session': _vigie.session,
    });
    chrono.stop();

    final data = result.data as Map;
    final brut = data['parcours'];
    if (brut is! Map) {
      throw StateError('Réponse genererParcours sans parcours');
    }
    final map = Map<String, dynamic>.from(brut);
    final jours = (map['jours'] as List? ?? const [])
        .whereType<Map>()
        .map((j) => ParcoursJour.fromJson(Map<String, dynamic>.from(j)))
        .toList();
    if (jours.length != 7) {
      throw StateError('Parcours reçu avec ${jours.length} jours');
    }

    final fallback = data['fallback'] == true;
    _vigie.log('parcours_genere', {
      'ms': chrono.elapsedMilliseconds,
      'fallback': fallback,
    });

    return ParcoursGenere(
      parcours: ParcoursModel(
        titre: map['titre'] as String? ?? '',
        sousTitre: map['sousTitre'] as String? ?? '',
        jours: jours,
        creeLe: DateTime.now().toIso8601String(),
      ),
      messageOuverture: (map['messageOuverture'] as String?)?.trim() ?? '',
      fallback: fallback,
    );
  }
}
