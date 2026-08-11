import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/config/revenue_cat_config.dart';

/// Charge l'Offering RevenueCat avec triple fallback :
/// 1. 'Abonnement' nommé (configuré dans le dashboard)
/// 2. offering current
/// 3. premier offering disponible
///
/// Préchargé au lancement de l'app (voir QuietoApp.initState) afin que le
/// paywall s'ouvre avec ses prix déjà en mémoire, sans délai ni roue de
/// chargement. PAS d'autoDispose : le cache doit survivre entre les écrans
/// (sinon il est jeté pile avant l'ouverture du paywall → saccade).
///
/// ⚠️ Résilience (bug 1.0.14, août 2026) : au démarrage à froid, le réseau ou
/// le store (StoreKit/Play Billing) n'est souvent pas encore prêt →
/// getOfferings échoue ou renvoie une offre SANS produit résolu. Le résultat
/// étant en cache pour toute la session, 36 % des ouvertures de paywall
/// tombaient sur « abonnements indisponibles » alors que tout était bien
/// configuré. Parade en deux volets : jusqu'à 3 tentatives ici, et PaywallPage
/// relance le chargement à chaque ouverture si le cache n'a pas d'offre
/// achetable.
final offeringProvider = FutureProvider<Offering?>((ref) async {
  // Clé absente du build → ne SURTOUT pas appeler le SDK natif : il
  // s'écraserait (fatalError, crash écran noir) au lieu de renvoyer une
  // erreur rattrapable.
  if (!revenueCatDisponible) {
    debugPrint('[Paywall] RevenueCat non configuré (clé absente) : '
        'aucun offering chargé.');
    return null;
  }
  const essais = 3;
  PlatformException? derniereErreur;
  for (var essai = 1; essai <= essais; essai++) {
    if (essai > 1) {
      // 1 s puis 2 s : le temps que le réseau et le store se lèvent.
      await Future<void>.delayed(Duration(seconds: essai - 1));
    }
    derniereErreur = null;
    try {
      debugPrint('[Paywall] Chargement des offerings ($essai/$essais)...');
      final offerings = await Purchases.getOfferings();
      final current = offerings.getOffering('Abonnement') ??
          offerings.current ??
          (offerings.all.isNotEmpty ? offerings.all.values.first : null);
      // Offre absente OU sans package achetable (produits non résolus côté
      // store) : même symptôme pour l'utilisateur — on retente.
      if (current != null && current.availablePackages.isNotEmpty) {
        debugPrint('[Paywall] Offering trouvé : ${current.identifier}');
        return current;
      }
      debugPrint('[Paywall] Offering vide ou sans produit (essai $essai).');
    } on PlatformException catch (e) {
      derniereErreur = e;
      debugPrint('[Paywall] Erreur getOfferings (essai $essai) : $e');
    }
  }
  // Tentatives épuisées sans exception : offres réellement vides → null
  // propre, l'écran « abonnements indisponibles » propose de réessayer.
  final e = derniereErreur;
  if (e == null) return null;
  // ConfigurationError (code 23) = aucun produit configuré pour CETTE
  // plateforme. PurchaseNotAllowedError (code 3) = billing indisponible sur
  // l'appareil (émulateur sans Play Store, appareil sans services Google).
  // Ce ne sont PAS des pannes : null → « aucun abonnement disponible » au
  // lieu d'une erreur technique brute.
  final code = PurchasesErrorHelper.getErrorCode(e);
  if (code == PurchasesErrorCode.configurationError ||
      code == PurchasesErrorCode.purchaseNotAllowedError) {
    return null;
  }
  throw e;
});
