import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/category_model.dart';
import '../home/home_providers.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final filteredCategoriesProvider = Provider<List<CategoryModel>>((ref) {
  final categories = ref.watch(categoriesProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  if (query.isEmpty) return categories;

  return categories.where((cat) {
    final matchCategory =
        cat.name.toLowerCase().contains(query) ||
        cat.description.toLowerCase().contains(query);
    final matchSession = cat.sessions.any(
      (s) => s.title.toLowerCase().contains(query),
    );
    return matchCategory || matchSession;
  }).toList();
});
