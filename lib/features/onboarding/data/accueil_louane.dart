import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/services/identite_firebase.dart';
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
      await assurerIdentiteFirebase();
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
              ?.map((b) => avecMajuscule(b.toString().trim()))
              .where((b) => b.isNotEmpty)
              .take(2)
              .toList() ??
          const <String>[];
      if (bulles.isEmpty) {
        return (bulles: accueilDeRepli(prenom, profil), repli: true);
      }
      // La dernière bulle ne vient jamais du modèle : c'est l'invitation à
      // l'exercice, donc le bouton. Elle doit être exactement la même pour
      // tout le monde, à la virgule près.
      return (bulles: [...bulles, kInvitationEssai], repli: false);
    } catch (_) {
      // Réseau coupé, serveur en froid, délai dépassé : la personne ne doit
      // jamais le savoir.
      return (bulles: accueilDeRepli(prenom, profil), repli: true);
    }
  }
}

/// La dernière bulle de l'accueil, toujours identique : elle amène l'exercice
/// de respiration, donc le bouton. Écrite à la main, jamais générée — une
/// invitation à agir se teste et se garde stable.
const kInvitationEssai =
    'On a qu\'à essayer tout de suite pendant 30 secondes et tu me diras si '
    'ça te fait du bien ;)';

/// Majuscule en début de bulle. Le modèle écrit souvent en minuscule pour
/// faire naturel ; en début de message, ça se lit comme une phrase coupée.
/// On cherche la première LETTRE (une bulle peut ouvrir sur un guillemet ou
/// une ponctuation) et on la relève si besoin.
String avecMajuscule(String texte) {
  for (var i = 0; i < texte.length; i++) {
    final c = texte[i];
    if (c.toLowerCase() == c.toUpperCase()) continue; // pas une lettre
    if (c == c.toUpperCase()) return texte; // déjà en majuscule
    return texte.replaceRange(i, i + 1, c.toUpperCase());
  }
  return texte;
}

/// Le résumé écrit à l'avance, construit à partir des mêmes réponses. Il doit
/// tenir tout seul : c'est lui que verront les gens sans réseau. Même
/// structure que la consigne serveur : le fond, puis les habitudes, puis
/// l'invitation commune.
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
    avecMajuscule(
      debutante
          ? '$duree $moment, en partant de zéro : c\'est exactement comme ça '
              'que ça tient.'
          : '$duree $moment, c\'est jouable même les jours chargés.',
    ),
    // 3 · l'invitation, la même que sur le chemin serveur
    kInvitationEssai,
  ];
}
