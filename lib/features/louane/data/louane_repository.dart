import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/services/storage_service.dart';

/// Appelle la Cloud Function "louane" (le serveur) et renvoie sa réponse.
/// Gère aussi la MÉMOIRE locale : on envoie ce que Louane sait déjà (stocké sur
/// le téléphone) et on sauvegarde la fiche mise à jour qu'elle renvoie.
class LouaneRepository {
  LouaneRepository(this._storage);

  final StorageService _storage;

  Future<String> envoyer(
    String message,
    List<Map<String, String>> historique,
  ) async {
    // Heure locale du téléphone (ex. "23:47") → Louane salue au bon moment.
    final maintenant = DateTime.now();
    final heure = '${maintenant.hour.toString().padLeft(2, '0')}:'
        '${maintenant.minute.toString().padLeft(2, '0')}';

    final callable = FirebaseFunctions.instance.httpsCallable('louane');
    final result = await callable.call(<String, dynamic>{
      'message': message,
      'historique': historique,
      'heure': heure,
      'prenom': _storage.firstName,
      'memoire': _storage.louaneMemoire,
    });
    final data = result.data as Map;

    // Le serveur renvoie la fiche mémoire mise à jour → on la garde sur le tél.
    final nouvelleMemoire = (data['memoire'] as String?)?.trim();
    if (nouvelleMemoire != null &&
        nouvelleMemoire != _storage.louaneMemoire) {
      await _storage.setLouaneMemoire(nouvelleMemoire);
    }

    return (data['reponse'] as String?)?.trim() ?? '';
  }
}
