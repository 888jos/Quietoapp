import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_constants.dart';
import '../config/revenue_cat_config.dart';
import 'abonnement_serveur.dart';
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

  /// Vrai quand Paul a forcé l'état depuis l'interrupteur de test du profil
  /// (builds debug uniquement) : les mises à jour RevenueCat de la session
  /// sont alors ignorées pour ne pas écraser le forçage.
  bool _forceDebug = false;

  /// Bascule Premium pour tester l'app abonnée — ne fait RIEN hors debug.
  void debugForcerPremium(bool actif) {
    if (!kDebugMode) return;
    _forceDebug = true;
    _storage.setIsPremium(actif);
    state = actif;
  }

  void _handleUpdate(CustomerInfo info) {
    if (_forceDebug) return;
    final isPremium = info.entitlements.active
        .containsKey(AppConstants.entitlementPremium);
    // Persiste pour que le prochain démarrage parte avec le bon état.
    _storage.setIsPremium(isPremium);
    state = isPremium;
    // Le serveur relit RevenueCat et pose le claim `premium` (accès aux
    // MP3 premium dès l'achat, retrait dès l'expiration).
    unawaited(synchroniserAbonnementServeur());
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
