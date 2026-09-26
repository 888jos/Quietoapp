import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/category_model.dart';
import '../../core/services/storage_providers.dart';
import '../explore/explore_providers.dart';
import 'data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(exploreRepositoryProvider));
});

final categoriesProvider = Provider<List<CategoryModel>>((ref) {
  // Exclut decouverte (Priorité du moment). Ordre voulu : actualité en
  // tête, express (micro-méditations Flash) tout en bas.
  final all = ref
      .watch(homeRepositoryProvider)
      .fetchCategories()
      .where((c) => c.id != 'decouverte')
      .toList();
  final actualite = all.where((c) => c.id == 'actualite').toList();
  final express = all.where((c) => c.id == 'express').toList();
  final rest = all
      .where((c) => c.id != 'actualite' && c.id != 'express')
      .toList();
  return [...actualite, ...rest, ...express];
});

final userFirstNameProvider = Provider<String>((ref) {
  return ref.watch(firstNameProvider);
});
