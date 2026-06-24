import 'package:cloud_functions/cloud_functions.dart';

/// Appelle la Cloud Function "louane" (le serveur) et renvoie sa réponse.
class LouaneRepository {
  Future<String> envoyer(
    String message,
    List<Map<String, String>> historique,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable('louane');
    final result = await callable.call(<String, dynamic>{
      'message': message,
      'historique': historique,
    });
    final data = result.data as Map;
    return (data['reponse'] as String?)?.trim() ?? '';
  }
}
