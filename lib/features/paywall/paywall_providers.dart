import 'package:flutter/foundation.dart';
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
  } catch (e) {
    debugPrint('[Paywall] Erreur lors du chargement : $e');
    rethrow;
  }
});
