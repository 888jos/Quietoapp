import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/category_model.dart';
import 'data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository();
});

final categoriesProvider = Provider<List<CategoryModel>>((ref) {
  return ref.watch(homeRepositoryProvider).fetchCategories();
});

final featuredCategoryProvider = Provider<CategoryModel?>((ref) {
  final categories = ref.watch(categoriesProvider);
  return categories.isNotEmpty ? categories.first : null;
});
