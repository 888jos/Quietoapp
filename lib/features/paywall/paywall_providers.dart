import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Charge l'Offering RevenueCat avec triple fallback :
/// 1. 'Abonnement' nommé (configuré dans le dashboard)
/// 2. offering current
/// 3. premier offering disponible
///
/// Préchargé au lancement de l'app (voir QuietoApp.initState) afin que le
/// paywall s'ouvre avec ses prix déjà en mémoire, sans délai ni roue de
/// chargement. PAS d'autoDispose : le cache doit survivre entre les écrans
/// (sinon il est jeté pile avant l'ouverture du paywall → saccade).
final offeringProvider = FutureProvider<Offering?>((ref) async {
  try {
    debugPrint('[Paywall] Chargement des offerings...');
    final offerings = await Purchases.getOfferings();
    final current = offerings.getOffering('Abonnement') ??
        offerings.current ??
        (offerings.all.isNotEmpty ? offerings.all.values.first : null);
    if (current != null) {
      debugPrint('[Paywall] Offering trouvé : ${current.identifier}');
    } else {
      debugPrint('[Paywall] Aucun offering trouvé.');
    }
    return current;
  } on PlatformException catch (e) {
    // ConfigurationError (code 23) = aucun produit configuré pour CETTE
    // plateforme. C'est le cas Android tant que les abonnements ne sont pas
    // branchés sur le Play Store + RevenueCat. Ce n'est PAS une panne : on
    // renvoie null pour afficher proprement « aucun abonnement disponible »
    // au lieu d'une erreur technique brute.
    final code = PurchasesErrorHelper.getErrorCode(e);
    if (code == PurchasesErrorCode.configurationError) {
      debugPrint('[Paywall] Offerings non configurés sur cette plateforme : $e');
      return null;
    }
    debugPrint('[Paywall] Erreur lors du chargement : $e');
    rethrow;
  } catch (e) {
    debugPrint('[Paywall] Erreur lors du chargement : $e');
    rethrow;
  }
});
