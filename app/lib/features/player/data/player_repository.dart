import '../../../core/models/session_model.dart';
import '../../home/data/home_repository.dart';

class PlayerRepository {
  final HomeRepository _homeRepository;

  PlayerRepository(this._homeRepository);

  SessionModel? findSession(String sessionId) {
    final categories = _homeRepository.fetchCategories();
    for (final category in categories) {
      for (final session in category.sessions) {
        if (session.id == sessionId) return session;
      }
    }
    return null;
  }

}
