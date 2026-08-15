import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/vigie_service.dart';
import '../../louane/data/louane_repository.dart' show jourLocalEnFrancais;

/// Ce que renvoie le chargement : les bulles, et d'où elles viennent.
typedef AccueilResultat = ({List<String> bulles, bool repli});

/// L'accueil lancé D'AVANCE par l'écran de création de programme : ses 5 s de
/// compteur sont autant de temps de chargement gratuit, si bien qu'à l'arrivée
/// sur l'écran d'accueil les bulles sont déjà là — plus aucune attente à voir.
/// Null (saut direct par la barre de debug, ancien chemin) : l'écran d'accueil
/// lance le chargement lui-même.
final accueilPrechargeProvider =
    StateProvider<Future<AccueilResultat>?>((ref) => null);

/// L'accueil de Louane en fin d'onboarding : 2-3 bulles écrites à partir des
/// réponses au questionnaire.
///
/// Deux garde-fous, parce que c'est le tout premier contact et qu'un écran
/// vide ou une erreur y coûteraient bien plus cher qu'ailleurs :
///  - un DÉLAI D'ATTENTE court ([_delaiMax]) : au-delà, on n'attend plus ;
///  - un REPLI LOCAL ([accueilDeRepli]) écrit à partir des mêmes réponses,
///    qui part si le serveur traîne, tombe, ou renvoie du vide.
/// Dans les trois cas la personne voit un accueil normal : elle ne peut pas
/// distinguer le repli du texte du serveur.
class AccueilLouaneRepository {
  AccueilLouaneRepository(this._storage, this._vigie);

  final StorageService _storage;
  final VigieService _vigie;

  /// Au-delà, l'attente se voit et casse l'effet « elle m'écrit ».
  static const _delaiMax = Duration(seconds: 4);

  /// Renvoie les bulles d'accueil, et `true` si elles viennent du repli local
  /// (la Vigie s'en sert pour savoir à quelle fréquence le serveur lâche).
  Future<AccueilResultat> charger() async {
    final maintenant = DateTime.now();
    final prenom = _storage.firstName.trim();
    final profil = _storage.getOnboardingAnswers();
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('accueilOnboarding');
      final result = await callable.call(<String, dynamic>{
        'prenom': prenom,
        'profil': profil,
        'heure': '${maintenant.hour.toString().padLeft(2, '0')}:'
            '${maintenant.minute.toString().padLeft(2, '0')}',
        'jour': jourLocalEnFrancais(maintenant),
        'vigie': _vigie.id,
        'session': _vigie.session,
      }).timeout(_delaiMax);
      final data = result.data as Map;
      final bulles = (data['bulles'] as List?)
              ?.map((b) => b.toString().trim())
              .where((b) => b.isNotEmpty)
              .toList() ??
          const <String>[];
      if (bulles.isEmpty) {
        return (bulles: accueilDeRepli(prenom, profil), repli: true);
      }
      return (bulles: bulles, repli: false);
    } catch (_) {
      // Réseau coupé, serveur en froid, délai dépassé : la personne ne doit
      // jamais le savoir.
      return (bulles: accueilDeRepli(prenom, profil), repli: true);
    }
  }
}

/// Le résumé écrit à l'avance, construit à partir des mêmes réponses. Il doit
/// tenir tout seul : c'est lui que verront les gens sans réseau. Même
/// structure en trois temps que la consigne serveur — le fond, les
/// habitudes, l'invitation — pour que les deux versions se ressemblent.
List<String> accueilDeRepli(String prenom, Map<String, String> profil) {
  final priorite = (profil['q1'] ?? '').trim().isNotEmpty
      ? profil['q1']!.trim()
      : (profil['goals'] ?? '').split('|').firstWhere(
            (g) => g.isNotEmpty,
            orElse: () => '',
          );

  // Ce qui pèse, reformulé — jamais la case cochée telle quelle.
  const parPriorite = <String, String>{
    'Mieux dormir':
        'Le soir, la tête continue de tourner alors que le corps voudrait '
            's\'arrêter.',
    'Apaiser mon stress':
        'Ça pousse toute la journée, et ça ne redescend jamais vraiment.',
    'Calmer mon anxiété':
        'Cette boule qui revient sans prévenir, même quand rien ne le justifie.',
    'Me reconcentrer':
        'L\'attention part dans tous les sens, et la journée file sans toi.',
    'Prendre soin de moi':
        'Tu passes après tout le reste, en général.',
  };

  final duree = switch (profil['q_minutes']) {
    'Moins de 5 minutes' => 'quelques minutes',
    'Environ 10 minutes' => 'dix minutes',
    'Plus de 15 minutes' => 'un quart d\'heure',
    _ => 'quelques minutes',
  };
  final moment = switch (profil['q4']) {
    'Le matin, au réveil' => 'au réveil',
    'En journée, pour souffler' => 'dans ta journée',
    'Le soir, pour tout relâcher' => 'le soir',
    _ => 'quand tu peux',
  };
  final debutante = (profil['q2'] ?? '').contains('Jamais');

  return [
    // 1 · le fond
    parPriorite[priorite] ??
        'Tu es venue chercher un peu de calme, et c\'est déjà un vrai pas.',
    // 2 · les habitudes
    debutante
        ? '$duree $moment, en partant de zéro : c\'est exactement comme ça '
            'que ça tient.'
        : '$duree $moment — c\'est jouable, même les jours chargés.',
    // 3 · l'invitation
    prenom.isEmpty
        ? 'Viens, on essaie tout de suite. Trente secondes, pas plus.'
        : 'Viens $prenom, on essaie tout de suite. Trente secondes, pas plus.',
  ];
}
