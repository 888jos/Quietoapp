import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'acces_entreprise.dart';

/// Demande au serveur de relire l'abonnement auprès de RevenueCat et de
/// poser le custom claim `premium` sur le compte Firebase (c'est ce claim
/// que lisent les règles Firebase Storage pour ouvrir les séances premium),
/// puis rafraîchit le jeton pour qu'il soit visible tout de suite.
///
/// À appeler au lancement et après chaque changement RevenueCat (achat,
/// restauration, expiration). Silencieux : null si pas de compte ou échec.
Future<bool?> synchroniserAbonnementServeur() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  try {
    final r = await FirebaseFunctions.instance
        .httpsCallable('synchroniserAbonnement')
        .call()
        .timeout(const Duration(seconds: 8));
    await user.getIdToken(true);
    final donnees = r.data as Map;
    final premium = donnees['premium'] == true;
    debugPrint('[Abonnement] serveur : premium=$premium');
    // Accès offert par l'employeur : nom à afficher, et Premium que le
    // serveur vient de reprolonger (nouvelle période payée) → on relit
    // RevenueCat pour qu'il s'affiche sans attendre.
    final entreprise = donnees['entreprise'];
    if (entreprise is Map) {
      await AccesEntreprise.memoriser(entreprise['nom'] as String?);
      if (entreprise['prolonge'] == true) {
        await AccesEntreprise.rafraichirPremium();
      }
    } else if (donnees.containsKey('entreprise')) {
      await AccesEntreprise.memoriser(null);
    }
    return premium;
  } catch (e) {
    debugPrint('[Abonnement] synchronisation serveur échouée : $e');
    return null;
  }
}
