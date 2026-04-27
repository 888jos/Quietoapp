import '../../../core/models/category_model.dart';
import '../../explore/data/explore_repository.dart';

class HomeRepository {
  final ExploreRepository _explore;
  HomeRepository(this._explore);

  List<CategoryModel> fetchCategories() => _explore.fetchCategories();
}
