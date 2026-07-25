import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/parcours_model.dart';
import '../../core/models/session_model.dart';
import '../../core/services/storage_providers.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vigie_service.dart';
import '../explore/data/explore_repository.dart';
import '../explore/explore_providers.dart';
import 'data/parcours_repository.dart';

final parcoursRepositoryProvider = Provider<ParcoursRepository>(
  // Même précaution que louaneRepositoryProvider : l'abonnement est LU au
  // moment de l'appel, pas observé (un achat ne reconstruit rien).
  (ref) => ParcoursRepository(
    ref.watch(storageServiceProvider),
    ref.watch(vigieProvider),
    () => ref.read(subscriptionProvider),
  ),
);

/// L'état du programme en cours : null = aucun. Chargé depuis le stockage à
/// la construction (avec auto-réparation si le catalogue a bougé), persisté
/// à chaque changement.
class ParcoursNotifier extends StateNotifier<ParcoursModel?> {
  ParcoursNotifier(this._storage, this._vigie, this._explore) : super(null) {
    _chargerEtReparer();
  }

  final StorageService _storage;
  final VigieService _vigie;
  final ExploreRepository _explore;

  List<SessionModel> get _toutesSeances => _explore
      .fetchCategories()
      .expand((c) => c.sessions)
      .toList(growable: false);

  /// Auto-réparation au chargement : si un sessionId du programme n'existe
  /// plus dans le catalogue de l'app (app plus vieille que le serveur, ou
  /// séance retirée), on substitue une séance de la même catégorie (préfixe
  /// de l'id) pas encore utilisée, sinon la première découverte. L'affichage
  /// repart des infos de la séance de remplacement.
  void _chargerEtReparer() {
    final parcours = _storage.loadParcours();
    if (parcours == null) return;

    final seances = _toutesSeances;
    final parId = {for (final s in seances) s.id: s};
    final idsUtilises = parcours.jours.map((j) => j.sessionId).toSet();
    var repare = false;

    final jours = parcours.jours.map((j) {
      if (parId.containsKey(j.sessionId)) return j;
      final categorie = j.sessionId.split('_').first;
      final remplacement = seances
              .where((s) =>
                  s.categoryId == categorie && !idsUtilises.contains(s.id))
              .firstOrNull ??
          seances.where((s) => !idsUtilises.contains(s.id)).firstOrNull;
      if (remplacement == null) return j;
      repare = true;
      idsUtilises.add(remplacement.id);
      return j.copyWith(
        sessionId: remplacement.id,
        titreSeance: remplacement.title,
        dureeMin: remplacement.durationMinutes,
        premium: remplacement.isPremium,
      );
    }).toList();

    final resultat = repare ? parcours.copyWith(jours: jours) : parcours;
    if (repare) {
      _storage.saveParcours(resultat);
      _vigie.log('parcours_repare');
    }
    state = resultat;
  }

  /// Persiste et installe un programme fraîchement généré.
  Future<void> enregistrer(ParcoursModel parcours) async {
    await _storage.saveParcours(parcours);
    state = parcours;
  }

  /// Appelé par le lecteur quand une séance est écoutée jusqu'au bout : si
  /// c'est LA séance du jour en cours (et qu'aucun jour n'a déjà été validé
  /// aujourd'hui), le jour est coché. Réécouter un jour passé ne compte pas.
  Future<void> seanceTerminee(String sessionId) async {
    final parcours = state;
    if (parcours == null || parcours.termine || parcours.tousJoursTermines) {
      return;
    }
    final quand = DateTime.now();
    final aujourdHui = ParcoursModel.cleJourLocal(quand);
    final duJour = parcours.seanceDuJour;
    if (duJour == null || duJour.sessionId != sessionId) return;
    if (parcours.seanceDuJourFaite(aujourdHui)) return;

    final maj = parcours.marquerJourTermine(parcours.jourCourant, quand);
    await _storage.saveParcours(maj);
    state = maj;
    _vigie.log('parcours_jour_termine', {'jour': parcours.jourCourant});
  }

  /// Le bilan de fin de semaine (le ressenti part ensuite dans le chat, via
  /// LouaneChatNotifier — pas ici).
  Future<void> validerBilan(String ressenti) async {
    final parcours = state;
    if (parcours == null) return;
    final maj = parcours.avecBilan(ressenti);
    await _storage.saveParcours(maj);
    state = maj;
    _vigie.log('parcours_bilan', {'ressenti': ressenti});
  }

  /// « Arrêter ce programme » : on efface tout. Louane pourra en re-proposer
  /// un (le payload `parcours` redevient absent).
  Future<void> abandonner() async {
    final jour = state?.jourCourant ?? 0;
    await _storage.clearParcours();
    state = null;
    _vigie.log('parcours_abandonne', {'jour': jour});
  }
}

final parcoursProvider =
    StateNotifierProvider<ParcoursNotifier, ParcoursModel?>(
  (ref) => ParcoursNotifier(
    ref.watch(storageServiceProvider),
    ref.watch(vigieProvider),
    ref.watch(exploreRepositoryProvider),
  ),
);
