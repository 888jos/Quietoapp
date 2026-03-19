import '../../../core/models/category_model.dart';
import '../../../core/models/session_model.dart';
import '../../explore/data/explore_repository.dart';

class HomeRepository {
  final ExploreRepository _explore;
  HomeRepository(this._explore);

  List<CategoryModel> fetchCategories() => _explore.fetchCategories();

  SessionModel fetchFeaturedSession() {
    final decouverte =
        fetchCategories().firstWhere((c) => c.id == 'decouverte');
    return decouverte.sessions.first;
  }
}
