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
  // Exclut decouverte (Priorité du moment) et express (bloc Une minute pour toi)
  final all = ref
      .watch(homeRepositoryProvider)
      .fetchCategories()
      .where((c) => c.id != 'decouverte' && c.id != 'express')
      .toList();
  final actualite = all.where((c) => c.id == 'actualite').toList();
  final rest = all.where((c) => c.id != 'actualite').toList();
  return [...actualite, ...rest];
});

/// Sessions du bloc Express ("Une minute pour toi") sur la Home.
final expressSessionsProvider = Provider<List<SessionModel>>((ref) {
  final categories = ref.watch(homeRepositoryProvider).fetchCategories();
  final express = categories.where((c) => c.id == 'express').toList();
  return express.isEmpty ? const [] : express.first.sessions;
});

final userFirstNameProvider = Provider<String>((ref) {
  return ref.watch(firstNameProvider);
});
