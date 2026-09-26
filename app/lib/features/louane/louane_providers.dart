import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/health_service.dart';
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
///
/// La troisième bulle n'est que le REPLI : quand les réponses d'onboarding
/// sont là, [questionIntroDepuisProfil] la remplace par une reformulation de
/// l'objectif choisi.
const List<String> kLouaneIntro = [
  'Hey',
  "Moi c'est Louane",
  "Alors dis-moi, qu'est-ce qui t'amène ici ? :)",
];

/// Chaque objectif du quiz, tourné vers la personne. VOLONTAIREMENT calqué
/// sur les mots des cartes cochées (retour de Paul, 17/08) : la preuve que
/// Louane a écouté, c'est de redire les mots que la personne a choisis, pas
/// d'en inventer de plus jolis. Publique pour les tests.
const Map<String, String> kObjectifsEnMots = {
  'Apaiser mon stress': 'apaiser ton stress',
  'Mieux dormir': 'mieux dormir',
  'Calmer mon anxiété': 'calmer ton anxiété',
  'Me reconcentrer': 'te reconcentrer',
  'Prendre soin de moi': 'prendre soin de toi',
};

/// Quand la personne a coché LES CINQ réponses, les réciter ferait inventaire
/// (et ne prouverait rien : elle a tout pris). Louane le dit franchement et
/// lui rend la main — la seule variante qui rouvre la question. Deux phrases :
/// [bullesDepuisSalutation] la coupe en deux bulles sur le « :) ». Publique
/// pour les tests.
const String kQuestionIntroToutCoche =
    "J'ai vu que t'avais coché les cinq réponses quand je t'ai demandé ce "
    "qui t'amenait :) Du coup c'est encore un peu flou pour moi, tu pourrais "
    "me dire ce qui t'amène le plus, selon toi ?";

/// La troisième bulle de la toute première ouverture : reformule TOUS les
/// objectifs cochés (le quiz est à choix multiples — un seul objectif redit
/// alors que la personne en a coché trois, et Louane a l'air de n'avoir
/// écouté qu'à moitié). Un seul : « t'es surtout là pour X » ; plusieurs :
/// « t'es là pour X, Y et Z » ; les cinq : [kQuestionIntroToutCoche]. Le
/// « bien » de « c'est bien ça ? » adoucit la confirmation (demande de Paul).
/// Repli sur la question générique de [kLouaneIntro] si rien d'exploitable
/// (vieux compte, onboarding sauté, objectifs renommés). Publique pour les
/// tests.
String questionIntroDepuisProfil(Map<String, String> profil) {
  final enMots = (profil['goals'] ?? '')
      .split('|')
      .map((g) => kObjectifsEnMots[g.trim()])
      .whereType<String>()
      .toList();
  // Profil sans liste mais avec une priorité (`q1`) : elle fait l'affaire.
  if (enMots.isEmpty) {
    final seul = kObjectifsEnMots[(profil['q1'] ?? '').trim()];
    if (seul == null) return kLouaneIntro.last;
    enMots.add(seul);
  }
  if (enMots.length == kObjectifsEnMots.length) return kQuestionIntroToutCoche;
  if (enMots.length == 1) {
    return "Du coup si j'ai bien compris, t'es surtout là pour "
        "${enMots.first}, c'est bien ça ?";
  }
  final tous = enMots.length == 2
      ? '${enMots.first} et ${enMots.last}'
      : '${enMots.sublist(0, enMots.length - 1).join(', ')} '
          'et ${enMots.last}';
  return "Du coup si j'ai bien compris, t'es là pour $tous, c'est bien ça ?";
}

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
    // La question d'ouverture reprend les objectifs de l'onboarding : la
    // personne y a déjà dit ce qui l'amène, Louane montre qu'elle a suivi.
    // Seule la variante « tout coché » se découpe (deux phrases, deux
    // bulles) : le découpeur isolerait le « :) » final de la générique.
    final question = questionIntroDepuisProfil(_storage.getOnboardingAnswers());
    final bulles = [
      LouaneMessage(auteur: AuteurMessage.louane, texte: _accroche()),
      if (premiereFois) ...[
        LouaneMessage(auteur: AuteurMessage.louane, texte: kLouaneIntro[1]),
        ...(question == kQuestionIntroToutCoche
                ? bullesDepuisSalutation(question)
                : [question])
            .map((t) => LouaneMessage(auteur: AuteurMessage.louane, texte: t)),
      ] else
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
      // Louane « analyse » le questionnaire Santé (marqueur [ANALYSE] du
      // serveur, levé seulement si un questionnaire est lisible ici) : la
      // carte animée d'abord, seule dans le fil, sans indicateur de frappe ;
      // ses bulles n'arrivent qu'après, tapées comme d'habitude.
      final analyse =
          reponse.analyseSante ? HealthService.instance.analyseSante : null;
      // Réponse en plusieurs petites bulles tapées à la suite (comme
      // l'accueil) : le serveur envoie le découpage, l'app anime la frappe.
      // Les pièces jointes (séance, boutons) vont sur la DERNIÈRE bulle.
      final bulles =
          reponse.bulles.isNotEmpty ? reponse.bulles : [reponse.texte];
      // La carte « Louane analyse » se glisse après la bulle d'accord (« Ok,
      // on part là-dessus »), avant ce qu'elle a compris : la position vient
      // du serveur (l'endroit du marqueur), bornée pour qu'il reste toujours
      // au moins une bulle après la carte.
      final carteApres =
          analyse == null ? -1 : reponse.analyseApres.clamp(0, bulles.length - 1);
      for (var i = 0; i < bulles.length; i++) {
        final derniere = i == bulles.length - 1;
        var apresCarte = false;
        if (i == carteApres) {
          _vigie.log('sante_analyse_affichee', {'test': analyse!.test.name});
          state = state.copyWith(
            messages: [
              ...state.messages,
              LouaneMessage(
                auteur: AuteurMessage.louane,
                texte: '',
                analyse: analyse,
                analyseDebut: DateTime.now(),
              ),
            ],
            louaneEcrit: false,
          );
          await Future.delayed(analyse.duree);
          if (!mounted) return;
          apresCarte = true;
        }
        // Après la carte d'analyse, même la première bulle se fait attendre :
        // Louane finit de lire, puis écrit.
        if (i > 0 || apresCarte) {
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
              porteAnalyse: i == carteApres,
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

  /// Chaque message reçoit sa date en entrant dans le fil, quel que soit
  /// l'endroit du code qui l'y met (l'en-tête du menu contextuel l'affiche).
  @override
  set state(LouaneChatState valeur) {
    final maintenant = DateTime.now();
    var change = false;
    final messages = <LouaneMessage>[
      for (final m in valeur.messages)
        if (m.date == null) ...[
          () {
            change = true;
            return m.avecDate(maintenant);
          }(),
        ] else
          m,
    ];
    super.state = change ? valeur.copyWith(messages: messages) : valeur;
  }

  /// Renvoie un message de la personne, tel quel ou modifié (appui long sur
  /// sa bulle → « Modifier » / « Renvoyer », demande de Paul du 22/09/2026).
  /// Comme dans une conversation avec Claude : le fil est ramené juste AVANT
  /// ce message — la réponse de Louane et tout ce qui suit disparaissent —
  /// puis le texte part comme un nouveau message, et Louane répond à nouveau.
  /// Compte comme un message (c'est une vraie réponse de plus côté serveur).
  Future<void> renvoyer(int index, String texte) async {
    if (state.louaneEcrit) return;
    final messages = state.messages;
    if (index < 0 || index >= messages.length) return;
    final ancien = messages[index];
    if (ancien.auteur != AuteurMessage.user) return;
    _vigie.log('louane_message_renvoye', {
      'modifie': texte.trim() != ancien.texte,
      'retires': messages.length - index,
    });
    state = state.copyWith(messages: messages.sublist(0, index));
    await envoyer(texte);
  }

  /// Retire un message de la personne et la réponse de Louane qui le suit
  /// (jusqu'à son message suivant). Rien n'est renvoyé au serveur. Renvoie
  /// ce qui a été retiré, pour l'« Annuler » de la page ([restaurer]).
  List<LouaneMessage> supprimer(int index) {
    if (state.louaneEcrit) return const [];
    final messages = state.messages;
    if (index < 0 ||
        index >= messages.length ||
        messages[index].auteur != AuteurMessage.user) {
      return const [];
    }
    var fin = index + 1;
    while (fin < messages.length &&
        messages[fin].auteur != AuteurMessage.user) {
      fin++;
    }
    final retires = messages.sublist(index, fin);
    _vigie.log('louane_message_supprime', {'retires': retires.length});
    state = state.copyWith(
      messages: [...messages.sublist(0, index), ...messages.sublist(fin)],
    );
    return retires;
  }

  /// Annule une suppression : remet les messages retirés à leur place.
  void restaurer(int index, List<LouaneMessage> retires) {
    if (retires.isEmpty) return;
    final messages = state.messages;
    final i = index.clamp(0, messages.length);
    state = state.copyWith(
      messages: [...messages.sublist(0, i), ...retires, ...messages.sublist(i)],
    );
  }

  /// Glisse la bulle d'ouverture du programme dans le fil SANS appel serveur
  /// (« ton programme t'attend sur l'accueil »). Le texte vient du serveur et
  /// change à chaque génération : comparer les textes ne détecte donc jamais
  /// le doublon. Anti-empilement : recréer un programme (annuler puis
  /// re-cliquer) RETIRE la bulle d'ouverture précédente — il n'en reste
  /// qu'une, celle du programme qui existe vraiment.
  void ajouterBulleOuvertureParcours(String texte) {
    final t = texte.trim();
    if (t.isEmpty) return;
    state = state.copyWith(
      messages: [
        ...state.messages.where((m) => !m.estOuvertureParcours),
        LouaneMessage(
          auteur: AuteurMessage.louane,
          texte: t,
          estOuvertureParcours: true,
        ),
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
        .where((m) => m.auteur != AuteurMessage.systeme && !m.estCarteAnalyse)
        .map((m) => {
              'role': m.estLouane ? 'assistant' : 'user',
              'content': _contenuApi(m),
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

  /// Le texte d'un message tel que Louane l'avait écrit, marqueurs compris :
  /// le serveur les strippe de ses réponses, et sans eux Louane ne sait plus
  /// ce qu'elle a fait ([SEANCE:id] : quelle séance elle vient de lancer ;
  /// [ANALYSE] : qu'elle a déjà lu le questionnaire, la carte a été vue).
  static String _contenuApi(LouaneMessage m) {
    var texte = m.texte;
    if (m.porteAnalyse) texte = '[ANALYSE] $texte';
    if (m.seanceId != null) texte = '$texte [SEANCE:${m.seanceId}]';
    return texte;
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
        .where((m) => m.auteur != AuteurMessage.systeme && !m.estCarteAnalyse)
        .map((m) => {
              'role': m.estLouane ? 'assistant' : 'user',
              'content': _contenuApi(m),
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

/// Révélation de la barre de navigation sur l'onglet Louane, de 0 (rentrée
/// sous l'écran) à 1 (sortie). Choix de Paul (28/08) : elle se cache quand on
/// descend dans le fil et ne revient qu'en remontant. Retour du 12/09 : elle
/// SUIT LE GESTE au lieu de surgir entière au premier pixel — elle sort
/// proportionnellement au défilement vers le haut, et quand on lâche, elle
/// finit de sortir si elle est déjà bien révélée, sinon elle rentre. Les
/// autres onglets l'ignorent (toujours entière).
final louaneNavRevelationProvider = StateProvider<double>((ref) => 1.0);

/// L'avatar de Louane a quitté l'en-tête du chat pour venir « réfléchir »
/// au-dessus du popup d'analyse Santé (demande de Paul, 12/09) : l'en-tête
/// le cache le temps du vol aller-retour.
final louaneAvatarEnVolProvider = StateProvider<bool>((ref) => false);
