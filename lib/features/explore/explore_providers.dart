import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/router.dart';
import '../../core/models/category_model.dart';
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

/// Calcule la route de destination quand l'utilisateur tape sur une catégorie.
/// Premium + non abonné → paywall en montée glissée. Sinon → /category/:id.
final categoryRouteProvider =
    Provider.family<String, String>((ref, categoryId) {
  final category = ref.watch(categoryByIdProvider(categoryId));
  if (category == null || !category.isPremium) {
    return AppRoutes.categoryPath(categoryId);
  }
  final isSubscribed = ref.watch(subscriptionProvider);
  return isSubscribed
      ? AppRoutes.categoryPath(categoryId)
      : AppRoutes.paywallSlide;
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final categories = ref.watch(exploreCategoriesProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return categories;

  return categories.where((cat) {
    final matchCategory = cat.name.toLowerCase().contains(query) ||
        cat.description.toLowerCase().contains(query);
    final matchSession =
        cat.sessions.any((s) => s.title.toLowerCase().contains(query));
    return matchCategory || matchSession;
  }).toList();
});
