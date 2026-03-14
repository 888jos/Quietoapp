import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

/// Provider global pour StorageService.
/// Doit être overridé dans le ProviderScope de main.dart.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

/// Statut d'abonnement de l'utilisateur.
/// false par défaut — sera connecté à RevenueCat ultérieurement.
final subscriptionProvider = Provider<bool>((ref) {
  return ref.watch(storageServiceProvider).isPremium;
});
