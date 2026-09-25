import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Le serveur exige un jeton Firebase (EXIGER_AUTH, 12/09/2026). Si la
/// connexion anonyme du démarrage a échoué (réseau lent, mode avion), on la
/// retente juste avant d'appeler Louane, le programme ou l'accueil — sinon la
/// personne recevrait « Connexion requise » jusqu'au prochain redémarrage.
/// Jamais bloquant : en cas d'échec, l'appel part quand même et c'est le
/// serveur qui répond.
Future<void> assurerIdentiteFirebase() async {
  if (FirebaseAuth.instance.currentUser != null) return;
  try {
    await FirebaseAuth.instance
        .signInAnonymously()
        .timeout(const Duration(seconds: 6));
    debugPrint('[Identité] connexion anonyme rattrapée');
  } catch (e) {
    debugPrint('[Identité] connexion anonyme toujours impossible : $e');
  }
}
