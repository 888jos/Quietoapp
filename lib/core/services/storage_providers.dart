import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';

/// Provider global pour StorageService.
/// Doit être overridé dans le ProviderScope de main.dart.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

/// Prénom de l'utilisateur — StateProvider pour être réactif
/// (mis à jour par ProfileNotifier, lu par la home et le profil).
final firstNameProvider = StateProvider<String>((ref) {
  return ref.read(storageServiceProvider).firstName;
});

/// Statut d'abonnement de l'utilisateur.
/// false par défaut — sera connecté à RevenueCat ultérieurement.
///
/// DEV : mettre à true pour bypasser le paywall pendant le développement.
/// PROD : remettre à false avant de releaser.
const bool _devUnlockPremium = false;

final subscriptionProvider = Provider<bool>((ref) {
  if (_devUnlockPremium) return true;
  return ref.watch(storageServiceProvider).isPremium;
});
