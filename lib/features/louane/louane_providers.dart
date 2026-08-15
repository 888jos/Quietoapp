import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/storage_providers.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/vigie_service.dart';
import 'data/louane_message.dart';
import 'data/louane_repository.dart';

final louaneRepositoryProvider = Provider<LouaneRepository>(
  // subscriptionProvider est LU (read) et non observé (watch) : un achat en
  // pleine conversation ne doit pas reconstruire le repo → ce qui remettrait
  // la conversation à zéro via louaneChatProvider.
  (ref) => LouaneRepository(
    ref.watch(storageServiceProvider),
    ref.watch(vigieProvider),
    () => ref.read(subscriptionProvider),
  ),
);

/// État de la conversation : la liste des messages + si Louane est en train
/// d'écrire (pour afficher l'indicateur "…"). [plafondEvenement] s'incrémente
/// chaque fois que le serveur signale le plafond du jour — la page l'écoute
/// pour faire glisser la feuille « Louane se repose ».
class LouaneChatState {
  final List<LouaneMessage> messages;
  final bool louaneEcrit;
  final int plafondEvenement;

  const LouaneChatState({
    this.messages = const [],
    this.louaneEcrit = false,
    this.plafondEvenement = 0,
  });

  LouaneChatState copyWith({
    List<LouaneMessage>? messages,
    bool? louaneEcrit,
    int? plafondEvenement,
  }) {
    return LouaneChatState(
      messages: messages ?? this.messages,
      louaneEcrit: louaneEcrit ?? this.louaneEcrit,
      plafondEvenement: plafondEvenement ?? this.plafondEvenement,
    );
  }
}

/// L'accueil de Louane : trois bulles tapées à la suite à la toute première
/// ouverture. Textes en dur : majuscule en début de message, pas d'emoji,
/// pas de tiret long (émoticônes texte uniquement, genre ":)"). Public pour
/// le test qui vérifie ces règles.
const List<String> kLouaneIntro = [
  'Hey',
  "Moi c'est Louane",
  "Alors dis-moi, qu'est-ce qui t'amène ici ? :)",
];

/// Les phrases d'accueil des sessions suivantes, selon l'heure locale
/// (0-23). Plusieurs variantes par créneau, tirées au sort, pour que celui
/// qui revient chaque jour à la même heure ne lise pas deux fois la même.
/// Formulations neutres (jamais de « couché·e » genré). La bulle d'avant dit
/// déjà « Hey prénom » : donc JAMAIS de bonjour/bonsoir/salut ici, sinon
/// Louane salue deux fois de suite (effet robot). Publique pour les tests,
/// qui vérifient aussi les règles de style sur chaque variante.
List<String> salutationsPourHeure(int h) {
  if (h >= 5 && h < 8) {
    return [
      'Déjà debout ?',
      'La journée se lève à peine, prends ton temps',
      'Tôt ce matin... Profite, tout est calme',
      'Grosse journée devant toi ?',
    ];
  }
  if (h >= 8 && h < 12) {
    return [
      'Alors, elle démarre comment cette journée ?',
      "Alors, qu'est-ce que t'as prévu aujourd'hui ?",
      "Alors, t'as bien dormi ?",
      'En forme ce matin ?',
    ];
  }
  if (h >= 12 && h < 14) {
    return [
      'Petite pause de midi ? Raconte-moi ta matinée',
      'Alors, cette matinée ?',
      'Mi-journée :) Tu tiens le rythme ?',
      'Il se passe quoi de beau ce midi ?',
    ];
  }
  if (h >= 14 && h < 18) {
    return [
      'Ça me fait plaisir de te voir :) Quoi de neuf ?',
      "Alors, où t'en es de ta journée ?",
      'Tu tiens le coup cet aprèm ?',
      "Il te reste beaucoup à faire aujourd'hui ?",
      "T'arrives à souffler entre deux trucs ?",
      'Ça avance ta journée ?',
      'Tu peux te poser deux minutes là ?',
    ];
  }
  if (h >= 18 && h < 22) {
    return [
      'Alors, elle a donné quoi cette journée ?',
      "Alors, comment s'est passé aujourd'hui ?",
      'Tu fais quoi de ta soirée ?',
      "T'as réussi à souffler un peu aujourd'hui ?",
      'Ta soirée commence comment ?',
    ];
  }
  if (h >= 22 || h < 1) {
    return [
      'Pas encore au lit, toi :)',
      'La journée est enfin finie... Elle était comment ?',
      "C'est l'heure où la tête commence à tourner, non ?",
      "Fin de journée en douceur, j'espère",
    ];
  }
  return [
    "Qu'est-ce que tu fais debout en pleine nuit ?",
    "Qu'est-ce qui se passe ? Pourquoi t'es toujours debout ?",
    "T'arrives pas à dormir ?",
    "Tu veux qu'on parle un peu ?",
    "Ça fait longtemps que t'es debout ?",
    'Il se passe quoi cette nuit ?',
    "T'as essayé de dormir ou pas encore ?",
  ];
}

/// Découpe une phrase d'accueil en messages successifs : une fin de phrase
/// (`.`, `?`, `!`, `...` ou une émoticône `:)`) suivie d'une relance devient
/// un nouveau message — un humain n'enchaîne pas deux phrases dans le même
/// texto. « Bien dormi ? Sois honnête :) » → deux messages. Publique pour
/// les tests.
List<String> bullesDepuisSalutation(String texte) {
  final parts = <String>[];
  final fins = RegExp(r'(\.\.\.|[.?!]|:\))\s+');
  var debut = 0;
  for (final m in fins.allMatches(texte)) {
    parts.add(texte.substring(debut, m.end).trim());
    debut = m.end;
  }
  final reste = texte.substring(debut).trim();
  if (reste.isNotEmpty) parts.add(reste);
  return parts.isEmpty ? [texte] : parts;
}

class LouaneChatNotifier extends StateNotifier<LouaneChatState> {
  final LouaneRepository _repo;
  final VigieService _vigie;
  final bool Function() _estAbonne;
  final StorageService _storage;
  bool _introJouee = false;

  LouaneChatNotifier(this._repo, this._vigie, this._estAbonne, this._storage)
      : super(const LouaneChatState());

  String _salutationAleatoire() {
    final variantes = salutationsPourHeure(DateTime.now().hour);
    return variantes[Random().nextInt(variantes.length)];
  }

  /// « Hey Paul » si le prénom de l'onboarding est là, sinon « Hey ».
  String _accroche() {
    final prenom = _storage.firstName.trim();
    return prenom.isEmpty
        ? kLouaneIntro.first
        : '${kLouaneIntro.first} $prenom';
  }

  /// L'accueil, tapé en direct par Louane (une fois par session, appelé par
  /// la page après le disclaimer). Toute première ouverture : elle se
  /// présente (trois bulles). Sessions suivantes : « Hey Paul » puis une
  /// phrase adaptée à l'heure.
  Future<void> jouerIntro() async {
    if (_introJouee || state.messages.isNotEmpty) return;
    _introJouee = true;

    final premiereFois = _storage.louaneIntroVariante == null;
    final bulles = [
      LouaneMessage(auteur: AuteurMessage.louane, texte: _accroche()),
      if (premiereFois)
        ...kLouaneIntro.skip(1).map(
            (t) => LouaneMessage(auteur: AuteurMessage.louane, texte: t))
      else
        // La salutation se découpe à chaque fin de phrase : « Bien dormi ?
        // Sois honnête :) » = deux messages, comme un humain.
        ...bullesDepuisSalutation(_salutationAleatoire()).map(
            (t) => LouaneMessage(auteur: AuteurMessage.louane, texte: t)),
    ];
    if (premiereFois) await _storage.setLouaneIntroVariante(0);

    // 0,5 s de silence, puis chaque bulle part après sa frappe (durée liée
    // à sa longueur) : c'est ce qui rend la frappe crédible.
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    for (var i = 0; i < bulles.length; i++) {
      state = state.copyWith(louaneEcrit: true);
      await Future.delayed(Duration(
          milliseconds: (bulles[i].texte.length * 30).clamp(700, 1700)));
      if (!mounted) return;
      state = state.copyWith(
        messages: bulles.sublist(0, i + 1),
        louaneEcrit: i < bulles.length - 1,
      );
    }
  }

  /// Fin des messages découverte — le mot de Louane validé (en attendant
  /// le vrai écran d'abonnement, branché avec StoreKit plus tard).
  static const _motPaywall =
      "J'ai adoré faire ta connaissance. Pour qu'on continue à se parler "
      "tous les jours, il y a Quieto Premium, et tu peux l'essayer 7 jours "
      "gratuitement. Je t'attends 🤍";

  /// Frein anti-spam : au-delà de [_maxRefusVerifies] refus (paywall/plafond)
  /// d'affilée, on cesse d'appeler le serveur — même le Veilleur (0,08 ¢/msg)
  /// ne doit pas tourner en boucle pour quelqu'un qui force. L'éthique reste
  /// couverte : le 3114 est écrit en toutes lettres dans la réponse locale.
  static const _maxRefusVerifies = 5;
  int _refusDeSuite = 0;
  bool _refusSousAbonne = false; // statut abonné au moment du dernier refus

  static const _motStop =
      "Je dois vraiment te laisser pour aujourd'hui 🤍 Et surtout, si tu "
      "traverses un moment difficile, le 3114 est là pour toi, 24h/24 et "
      "gratuitement.";

  Future<void> envoyer(String texte) async {
    final t = texte.trim();
    if (t.isEmpty || state.louaneEcrit) return;

    final avecUser = [
      ...state.messages,
      LouaneMessage(auteur: AuteurMessage.user, texte: t),
    ];
    state = state.copyWith(messages: avecUser, louaneEcrit: true);

    // Le statut d'abonnement a changé depuis le dernier refus (la personne
    // vient de s'abonner, par exemple) → on relâche le frein : le serveur
    // retranchera les vraies limites lui-même.
    if (_refusDeSuite > 0 && _estAbonne() != _refusSousAbonne) {
      _refusDeSuite = 0;
    }

    // Frein anti-spam : trop de refus d'affilée → réponse locale, zéro appel
    // serveur, zéro coût. Le 3114 reste écrit noir sur blanc.
    if (_refusDeSuite >= _maxRefusVerifies) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          const LouaneMessage(auteur: AuteurMessage.louane, texte: _motStop),
        ],
        louaneEcrit: false,
      );
      return;
    }

    try {
      final reponse = await _repo.envoyer(
        t,
        _historiquePourApi(avecUser),
        accueil: _accueilPourApi(avecUser),
      );

      // Plafond du jour atteint : pas de réponse, Louane dort — on prévient
      // la page (feuille qui glisse) sans rien ajouter au fil.
      if (reponse.plafond && reponse.texte.isEmpty) {
        _refusDeSuite++;
        _refusSousAbonne = _estAbonne();
        _vigie.log('louane_plafond', {'refus_de_suite': _refusDeSuite});
        state = state.copyWith(
          louaneEcrit: false,
          plafondEvenement: state.plafondEvenement + 1,
        );
        return;
      }

      // Messages découverte épuisés : Louane le dit avec ses mots, et la
      // page affiche le bouton « essai gratuit » sous la bulle.
      if (reponse.paywall && reponse.texte.isEmpty) {
        _refusDeSuite++;
        _refusSousAbonne = _estAbonne();
        _vigie.log('louane_paywall', {'refus_de_suite': _refusDeSuite});
        state = state.copyWith(
          messages: [
            ...state.messages,
            const LouaneMessage(
              auteur: AuteurMessage.louane,
              texte: _motPaywall,
              avecBoutonEssai: true,
            ),
          ],
          louaneEcrit: false,
        );
        return;
      }

      // Vraie réponse de Louane (ou message de sécurité du Veilleur).
      _refusDeSuite = 0;
      if (reponse.seanceId != null) {
        _vigie.log('louane_seance_proposee', {'seance': reponse.seanceId!});
      }
      // Louane propose le programme : bouton sous la bulle, seulement s'il
      // n'y a pas déjà un programme (le serveur vérifie aussi de son côté).
      final proposeParcours =
          reponse.parcoursPropose && _storage.loadParcours() == null;
      if (proposeParcours) {
        _vigie.log('parcours_propose');
      }
      // Filet : une réponse sans texte ni pièce jointe (vu quand la Voix
      // n'envoie qu'un marqueur, strippé côté serveur) → pas de bulle vide.
      if (reponse.texte.isEmpty &&
          reponse.seanceId == null &&
          !proposeParcours) {
        _vigie.log('louane_reponse_vide');
        state = state.copyWith(louaneEcrit: false);
        return;
      }
      // Réponse en plusieurs petites bulles tapées à la suite (comme
      // l'accueil) : le serveur envoie le découpage, l'app anime la frappe.
      // Les pièces jointes (séance, boutons) vont sur la DERNIÈRE bulle.
      final bulles =
          reponse.bulles.isNotEmpty ? reponse.bulles : [reponse.texte];
      for (var i = 0; i < bulles.length; i++) {
        final derniere = i == bulles.length - 1;
        if (i > 0) {
          state = state.copyWith(louaneEcrit: true);
          // Frappe crédible : durée liée à la longueur de la bulle qui vient.
          await Future.delayed(Duration(
              milliseconds: (bulles[i].length * 25).clamp(700, 1800)));
          if (!mounted) return;
        }
        state = state.copyWith(
          messages: [
            ...state.messages,
            LouaneMessage(
              auteur: AuteurMessage.louane,
              texte: bulles[i],
              seanceId: derniere ? reponse.seanceId : null,
              avecBoutonParcours: derniere && proposeParcours,
              // Dernier message découverte : l'au revoir de Louane porte
              // directement le bouton « essai gratuit ».
              avecBoutonEssai: derniere && reponse.finDecouverte,
            ),
          ],
          louaneEcrit: !derniere,
        );
      }
    } catch (e) {
      // L'erreur reste visible en console — le message doux, lui, à l'écran.
      // Vigie : un envoi qui échoue est un point de fuite technique majeur.
      _vigie.log('louane_erreur');
      debugPrint('[Louane] envoi échoué : $e');
      state = state.copyWith(
        messages: [
          ...state.messages,
          const LouaneMessage(
            auteur: AuteurMessage.louane,
            texte: "Je n'arrive pas à te répondre là, tout de suite… "
                "On réessaie dans un instant ?",
          ),
        ],
        louaneEcrit: false,
      );
    }
  }

  /// Glisse une bulle de Louane dans le fil SANS appel serveur : la bulle
  /// d'ouverture du programme (« ton programme t'attend sur l'accueil »).
  /// Anti-doublon : recréer un programme (supprimer puis re-cliquer) ne doit
  /// pas empiler la même bulle à chaque fois — si elle est déjà dans le fil,
  /// on la garde, c'est tout.
  void ajouterBulleLouane(String texte) {
    final t = texte.trim();
    if (t.isEmpty) return;
    if (state.messages.any((m) => m.estLouane && m.texte == t)) return;
    state = state.copyWith(
      messages: [
        ...state.messages,
        LouaneMessage(auteur: AuteurMessage.louane, texte: t),
      ],
    );
  }

  /// Fine ligne d'information centrée dans le fil (jamais envoyée au
  /// serveur). Une seule fois par texte : pas de doublon si l'événement
  /// se redéclenche.
  void ajouterLigneSysteme(String texte) {
    final t = texte.trim();
    if (t.isEmpty) return;
    if (state.messages
        .any((m) => m.auteur == AuteurMessage.systeme && m.texte == t)) {
      return;
    }
    state = state.copyWith(
      messages: [
        ...state.messages,
        LouaneMessage(auteur: AuteurMessage.systeme, texte: t),
      ],
    );
  }

  /// La conversation complète au format API (dernier message inclus) : c'est
  /// la matière première de la génération du programme.
  List<Map<String, String>> historiquePourParcours() {
    final mapped = state.messages
        .where((m) => m.auteur != AuteurMessage.systeme)
        .map((m) => {
              'role': m.estLouane ? 'assistant' : 'user',
              'content': m.texte,
            })
        .toList();
    // L'API exige que la conversation commence par un message "user".
    while (mapped.isNotEmpty && mapped.first['role'] == 'assistant') {
      mapped.removeAt(0);
    }
    return mapped;
  }

  /// Le bilan de fin de programme : composé en message utilisateur VISIBLE et
  /// envoyé par le pipeline normal → la Mémoire retient le ressenti, et la
  /// réponse de Louane arrive naturellement dans la conversation.
  Future<void> envoyerBilanParcours(String ressenti, String texteLibre) {
    final message = StringBuffer(
      "Ça y est, j'ai terminé le programme que tu m'avais préparé. "
      'Mon ressenti de la semaine : ${ressenti.toLowerCase()}.',
    );
    if (texteLibre.isNotEmpty) {
      message.write(' $texteLibre');
    }
    return envoyer(message.toString());
  }

  /// Les bulles d'accueil en dur (retirées de l'historique API ci-dessous) :
  /// envoyées à part pour que Louane sache ce qu'elle vient de dire.
  String _accueilPourApi(List<LouaneMessage> tous) {
    final textes = <String>[];
    for (final m in tous) {
      if (m.auteur == AuteurMessage.systeme) continue;
      if (!m.estLouane) break;
      textes.add(m.texte);
    }
    return textes.join('\n');
  }

  /// Transforme la conversation au format attendu par l'API (rôles
  /// user/assistant). On retire le dernier message (envoyé séparément) et tout
  /// message "assistant" en tête (ex: le mot d'accueil), car l'API exige que
  /// la conversation commence par un message "user".
  ///
  /// Les lancements de séance sont RÉINJECTÉS sous leur forme marqueur
  /// ([SEANCE:id] en fin de message, comme Louane les avait écrits) : le
  /// serveur les strippe de ses réponses, et sans eux Louane ne sait plus
  /// QUELLE séance elle vient de lancer — elle relançait la même en croyant
  /// en changer.
  List<Map<String, String>> _historiquePourApi(List<LouaneMessage> tous) {
    final precedents = tous.sublist(0, tous.length - 1);
    final mapped = precedents
        .where((m) => m.auteur != AuteurMessage.systeme)
        .map((m) => {
              'role': m.estLouane ? 'assistant' : 'user',
              'content': m.seanceId != null
                  ? '${m.texte} [SEANCE:${m.seanceId}]'
                  : m.texte,
            })
        .toList();
    while (mapped.isNotEmpty && mapped.first['role'] == 'assistant') {
      mapped.removeAt(0);
    }
    return mapped;
  }
}

final louaneChatProvider =
    StateNotifierProvider<LouaneChatNotifier, LouaneChatState>(
  (ref) => LouaneChatNotifier(
    ref.watch(louaneRepositoryProvider),
    ref.watch(vigieProvider),
    () => ref.read(subscriptionProvider),
    ref.watch(storageServiceProvider),
  ),
);
