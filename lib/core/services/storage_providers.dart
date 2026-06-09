import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_constants.dart';
import 'storage_service.dart';

/// Provider global pour StorageService.
/// Doit être overridé dans le ProviderScope de main.dart.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
      'storageServiceProvider must be overridden in ProviderScope');
});

/// Prénom de l'utilisateur — StateProvider pour être réactif
/// (mis à jour par ProfileNotifier, lu par la home et le profil).
final firstNameProvider = StateProvider<String>((ref) {
  return ref.read(storageServiceProvider).firstName;
});

/// DEV : mettre à true pour bypasser le paywall pendant le développement.
/// PROD : remettre à false avant de releaser.
const bool _devUnlockPremium = false;

/// Notifier qui maintient l'état "isPremium" en temps réel.
/// Écoute les mises à jour de RevenueCat via [Purchases.addCustomerInfoUpdateListener]
/// pour réagir instantanément à tout changement (achat, restauration, annulation,
/// expiration en milieu de session, etc.). Sans ça, l'état ne serait rafraîchi
/// qu'au prochain démarrage de l'app.
class SubscriptionNotifier extends StateNotifier<bool> {
  SubscriptionNotifier(this._storage, this._devUnlock)
      : super(_devUnlock || _storage.isPremium) {
    if (!_devUnlock) {
      Purchases.addCustomerInfoUpdateListener(_handleUpdate);
    }
  }

  final StorageService _storage;
  final bool _devUnlock;

  void _handleUpdate(CustomerInfo info) {
    final isPremium = info.entitlements.active
        .containsKey(AppConstants.entitlementPremium);
    state = isPremium;
    // Persiste pour que le prochain démarrage parte avec le bon état.
    _storage.setIsPremium(isPremium);
  }

  @override
  void dispose() {
    if (!_devUnlock) {
      Purchases.removeCustomerInfoUpdateListener(_handleUpdate);
    }
    super.dispose();
  }
}

/// Statut d'abonnement de l'utilisateur (true = premium actif).
/// API identique à avant : `ref.watch(subscriptionProvider)` renvoie un `bool`.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, bool>((ref) {
  return SubscriptionNotifier(
    ref.watch(storageServiceProvider),
    _devUnlockPremium,
  );
});
