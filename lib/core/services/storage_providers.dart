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

/// DEV : passe ce flag à true pour bypasser le paywall pendant le développement.
/// Garde-fou : grâce à `!kReleaseMode`, un build de RELEASE force TOUJOURS le
/// paywall (peu importe la valeur ci-dessous) — impossible de shipper le bypass.
const bool _kDevWantsPremiumBypass = false;
const bool _devUnlockPremium = !kReleaseMode && _kDevWantsPremiumBypass;

/// Notifier qui maintient l'état "isPremium" en temps réel.
/// Écoute les mises à jour de RevenueCat via [Purchases.addCustomerInfoUpdateListener]
/// pour réagir instantanément à tout changement (achat, restauration, annulation,
/// expiration en milieu de session, etc.). Sans ça, l'état ne serait rafraîchi
/// qu'au prochain démarrage de l'app.
class SubscriptionNotifier extends StateNotifier<bool> {
  SubscriptionNotifier(this._storage, this._devUnlock)
      : super(_devUnlock || _storage.isPremium) {
    // revenueCatDisponible : sans clé dans le build, tout appel au SDK
    // natif s'écrase (fatalError) au lieu de renvoyer une erreur.
    if (!_devUnlock && revenueCatDisponible) {
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

  /// DEV uniquement : bascule premium/gratuit à la volée (interrupteur de
  /// test dans le profil). No-op en release, même garde-fou que le bypass.
  /// PERSISTE le choix : un achat sandbox laisse isPremium=true dans le
  /// stockage, et sans clé RevenueCat dans le build (lancement Xcode) rien
  /// ne le remet jamais à false → tout reste déverrouillé, plus aucun
  /// paywall visible (vécu le 2026-07-24). Basculer l'interrupteur doit
  /// donc corriger le stockage aussi, durablement.
  void devTogglePremium() {
    if (kReleaseMode) return;
    state = !state;
    _storage.setIsPremium(state);
  }

  @override
  void dispose() {
    if (!_devUnlock && revenueCatDisponible) {
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
