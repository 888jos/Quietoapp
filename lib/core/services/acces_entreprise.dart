import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_constants.dart';
import '../config/revenue_cat_config.dart';

/// Accès Premium offert par l'employeur (B2B, 23/09/2026).
///
/// L'entreprise paie sur le web (Stripe) et reçoit un code (ex. ACME-7K2P).
/// Le salarié le tape dans Profil → « Accès offert par mon entreprise » :
/// la fonction `accesEntreprise` prend une place et ACCORDE Premium chez
/// RevenueCat. Premium arrive donc par le canal habituel (CustomerInfo →
/// SubscriptionNotifier) ; ici on retient juste le NOM de l'entreprise pour
/// l'afficher. Le serveur reprolonge l'accès à chaque lancement
/// (`synchroniserAbonnement`) tant que l'entreprise paie.
class AccesEntreprise {
  AccesEntreprise._();

  /// Nom de l'entreprise qui offre Premium sur ce compte (null = aucune).
  static final nom = ValueNotifier<String?>(null);
  static const _cle = 'entreprise_offrante';

  static Future<void> charger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      nom.value = prefs.getString(_cle);
    } catch (_) {}
  }

  static Future<void> memoriser(String? n) async {
    nom.value = (n == null || n.isEmpty) ? null : n;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (nom.value == null) {
        await prefs.remove(_cle);
      } else {
        await prefs.setString(_cle, nom.value!);
      }
    } catch (_) {}
  }

  /// Vérifie le code sans rien activer : renvoie le nom de l'entreprise.
  static Future<String> apercu(String code) async {
    final r = await _appeler({'code': code});
    return (r['nom'] as String?) ?? 'ton entreprise';
  }

  /// Prend une place et débloque Premium. Renvoie le nom de l'entreprise.
  static Future<String> activer(String code) async {
    final r = await _appeler({'code': code, 'confirmer': true});
    final n = (r['nom'] as String?) ?? 'ton entreprise';
    await memoriser(n);
    await rafraichirPremium();
    return n;
  }

  /// Relit l'abonnement chez RevenueCat : le listener de
  /// SubscriptionNotifier voit le droit accordé par le serveur.
  static Future<void> rafraichirPremium() async {
    if (!revenueCatDisponible) return;
    try {
      await Purchases.invalidateCustomerInfoCache();
      await Purchases.getCustomerInfo().timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[Entreprise] relecture RevenueCat échouée : $e');
    }
  }

  /// Abonnement PERSONNEL (App Store / Play) qui continuera d'être prélevé
  /// en plus de l'accès entreprise. null = aucun. Le développeur ne peut
  /// pas le résilier à la place de la personne (règle Apple).
  static Future<CustomerInfo?> abonnementPersonnelActif() async {
    if (!revenueCatDisponible) return null;
    try {
      final info =
          await Purchases.getCustomerInfo().timeout(const Duration(seconds: 6));
      final droit = info.entitlements.active[AppConstants.entitlementPremium];
      final personnel = droit != null &&
          droit.willRenew &&
          (droit.store == Store.appStore || droit.store == Store.playStore);
      return personnel ? info : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> _appeler(
      Map<String, dynamic> donnees) async {
    try {
      final r = await FirebaseFunctions.instance
          .httpsCallable('accesEntreprise')
          .call(donnees)
          .timeout(const Duration(seconds: 15));
      return Map<String, dynamic>.from(r.data as Map);
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final raison = details is Map ? details['raison'] as String? : null;
      // Les erreurs « métier » arrivent avec un message déjà rédigé.
      if (raison != null) {
        throw AccesEntrepriseErreur(raison, e.message ?? _messageParDefaut);
      }
      if (e.code == 'resource-exhausted') {
        throw const AccesEntrepriseErreur(
            'quota', 'Trop d\'essais pour aujourd\'hui. Réessaie demain.');
      }
      if (e.code == 'unavailable' && e.message != null) {
        throw AccesEntrepriseErreur('reseau', e.message!);
      }
      throw AccesEntrepriseErreur(e.code, _messageParDefaut);
    } on TimeoutException {
      throw const AccesEntrepriseErreur('reseau', _messageParDefaut);
    }
  }

  static const _messageParDefaut =
      'Impossible de vérifier le code pour l\'instant. Réessaie dans un instant.';
}

class AccesEntrepriseErreur implements Exception {
  /// compte | inconnu | inactif | complet | quota | reseau | code Firebase
  final String raison;
  final String message;
  const AccesEntrepriseErreur(this.raison, this.message);

  @override
  String toString() => message;
}
