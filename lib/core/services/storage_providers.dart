import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_constants.dart';
import '../config/revenue_cat_config.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'vigie_service.dart';

/// Provider global pour StorageService.
/// Doit être overridé dans le ProviderScope de main.dart.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
      'storageServiceProvider must be overridden in ProviderScope');
});

/// Vigie (mesure d'usage interne, anonyme).
/// Doit être overridé dans le ProviderScope de main.dart.
final vigieProvider = Provider<VigieService>((ref) {
  throw UnimplementedError(
      'vigieProvider must be overridden in ProviderScope');
});

/// Service des rappels quotidiens. Singleton sur la durée de vie de l'app ;
/// son init (plugin + timezone) est lazy, appelée par ses propres méthodes.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Prénom de l'utilisateur — StateProvider pour être réactif
/// (mis à jour par ProfileNotifier, lu par la home et le profil).
final firstNameProvider = StateProvider<String>((ref) {
  return ref.read(storageServiceProvider).firstName;
});

/// Notifier qui maintient l'état "isPremium" en temps réel.
/// Écoute les mises à jour de RevenueCat via [Purchases.addCustomerInfoUpdateListener]
/// pour réagir instantanément à tout changement (achat, restauration, annulation,
/// expiration en milieu de session, etc.). Sans ça, l'état ne serait rafraîchi
/// qu'au prochain démarrage de l'app.
class SubscriptionNotifier extends StateNotifier<bool> {
  SubscriptionNotifier(this._storage) : super(_storage.isPremium) {
    // revenueCatDisponible : sans clé dans le build, tout appel au SDK
    // natif s'écrase (fatalError) au lieu de renvoyer une erreur.
    if (revenueCatDisponible) {
      Purchases.addCustomerInfoUpdateListener(_handleUpdate);
    }
  }

  final StorageService _storage;

  /// DEV : premium forcé par l'interrupteur du profil (tournage des vidéos).
  /// Jamais persisté, et neutralisé en release (le bouton n'y existe pas et
  /// la méthode ne fait rien) : impossible de shipper le bypass.
  bool _devForce = false;

  void devForcerPremium(bool actif) {
    if (kReleaseMode) return;
    _devForce = actif;
    state = actif || _storage.isPremium;
  }

  void _handleUpdate(CustomerInfo info) {
    final isPremium = info.entitlements.active
        .containsKey(AppConstants.entitlementPremium);
    // Persiste pour que le prochain démarrage parte avec le bon état
    // (jamais le forçage de test, uniquement le vrai statut).
    _storage.setIsPremium(isPremium);
    state = _devForce || isPremium;
  }

  @override
  void dispose() {
    if (revenueCatDisponible) {
      Purchases.removeCustomerInfoUpdateListener(_handleUpdate);
    }
    super.dispose();
  }
}

/// Statut d'abonnement de l'utilisateur (true = premium actif).
/// API identique à avant : `ref.watch(subscriptionProvider)` renvoie un `bool`.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, bool>((ref) {
  return SubscriptionNotifier(ref.watch(storageServiceProvider));
});
