import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router.dart';
import '../../core/models/category_model.dart';
import '../../core/models/session_model.dart';
import '../../core/services/storage_providers.dart';
import '../player/player_providers.dart';
import 'data/explore_repository.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>(
  (_) => ExploreRepository(),
);

final exploreCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  return ref.watch(exploreRepositoryProvider).fetchCategories();
});

final categoryByIdProvider =
    Provider.family<CategoryModel?, String>((ref, id) {
  final categories = ref.watch(exploreCategoriesProvider);
  return categories.where((c) => c.id == id).firstOrNull;
});

/// Returns (completed, total) for a given category.
/// Watches [sessionCompletionTickProvider] so it re-reads SharedPreferences
/// every time a session is marked completed by the audio handler.
final categoryProgressProvider =
    Provider.family<({int completed, int total}), String>((ref, categoryId) {
  // Re-evaluate whenever a session completion is recorded.
  ref.watch(sessionCompletionTickProvider);
  final category = ref.watch(categoryByIdProvider(categoryId));
  if (category == null) return (completed: 0, total: 0);
  final progress = ref.watch(storageServiceProvider).loadProgress();
  final completed =
      category.sessions.where((s) => progress.isCompleted(s.id)).length;
  return (completed: completed, total: category.sessions.length);
});

/// Destination quand on tape sur une catégorie : TOUJOURS la page de la
/// catégorie, même premium. L'utilisateur peut parcourir librement les séances ;
/// le verrou ne se déclenche qu'à l'ouverture d'une séance payante (voir
/// [sessionLockedProvider]).
final categoryRouteProvider = Provider.family<String, String>(
  (ref, categoryId) => AppRoutes.categoryPath(categoryId),
);

/// true si la séance exige un abonnement que l'utilisateur n'a pas encore.
/// Règle unique : une séance est payante si elle est marquée premium OU si sa
/// catégorie l'est → toute séance d'une catégorie premium est payante.
final sessionLockedProvider =
    Provider.family<bool, SessionModel>((ref, session) {
  if (ref.watch(subscriptionProvider)) return false;
  if (session.isPremium) return true;
  final category = ref.watch(categoryByIdProvider(session.categoryId));
  return category?.isPremium ?? false;
});
