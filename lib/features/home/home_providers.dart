import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/category_model.dart';
import '../../core/models/session_model.dart';
import '../../core/services/storage_providers.dart';
import '../explore/explore_providers.dart';
import 'data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(exploreRepositoryProvider));
});

final categoriesProvider = Provider<List<CategoryModel>>((ref) {
  final all = ref
      .watch(homeRepositoryProvider)
      .fetchCategories()
      .where((c) => c.id != 'decouverte')
      .toList();
  final actualite = all.where((c) => c.id == 'actualite').toList();
  final rest = all.where((c) => c.id != 'actualite').toList();
  return [...actualite, ...rest];
});

final featuredSessionProvider = Provider<SessionModel>((ref) {
  return ref.watch(homeRepositoryProvider).fetchFeaturedSession();
});

final userFirstNameProvider = Provider<String>((ref) {
  return ref.watch(firstNameProvider);
});
