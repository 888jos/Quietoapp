import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:health/health.dart';

/// Envoie les minutes d'écoute dans Apple Santé (rubrique « Pleine
/// conscience »). iOS uniquement pour l'instant : le plugin `health` ne prend
/// pas encore en charge la pleine conscience sur Health Connect (Android).
///
/// Tous les appels sont silencieux : si l'utilisateur refuse l'accès Santé ou
/// si l'écriture échoue, la lecture audio et le comptage interne des minutes
/// ne sont jamais affectés.
class HealthService {
  HealthService._();
  static final HealthService instance = HealthService._();

  final Health _health = Health();
  bool _configured = false;
  bool _authRequestedThisRun = false;

  static const _types = [HealthDataType.MINDFULNESS];
  static const _permissions = [HealthDataAccess.WRITE];

  // Canal natif (ios/Runner/SanteMentaleChannel.swift) : lecture des
  // évaluations de bien-être d'Apple Santé (GAD-7 / PHQ-9, iOS 18+), que le
  // plugin `health` ne sait pas lire.
  static const _canalSante = MethodChannel('quieto/sante_mentale');

  String? _resumeSante; // cache session (null = jamais lu)
  Future<String>? _lectureSante; // dédoublonne les lectures concurrentes
  List<QuestionnaireSante> _questionnaires = const [];
  List<dynamic> _signauxBruts = const [];

  bool get _supported => !kIsWeb && Platform.isIOS;

  /// Vrai si l'appareil peut être relié à Apple Santé (iPhone). Sert à dire
  /// à Louane ce qui est possible ou non sur cet appareil.
  bool get disponible => _supported;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Affiche la demande d'accès à Apple Santé. iOS ne montre la feuille
  /// qu'une seule fois ; les appels suivants ne font rien de visible.
  /// Sur iOS 18+, la feuille combine écriture Pleine conscience et lecture
  /// des évaluations de bien-être ; sinon, repli sur le plugin (écriture).
  Future<void> requestAuthorization() async {
    if (!_supported || _authRequestedThisRun) return;
    _authRequestedThisRun = true;
    try {
      final ok = await _canalSante.invokeMethod<bool>('demanderAutorisation');
      if (ok == true) return;
    } catch (_) {
      // Canal absent (tests, vieille app) → repli plugin.
    }
    try {
      await _ensureConfigured();
      await _health.requestAuthorization(_types, permissions: _permissions);
    } catch (e) {
      debugPrint('[Health] demande d\'autorisation échouée: $e');
    }
  }

  /// État de la connexion à Santé, vu par l'écriture Pleine conscience
  /// (HealthKit cache volontairement les refus de lecture) :
  /// 'autorise', 'refuse', 'jamais', ou '' hors iPhone.
  Future<String> etatConnexion() async {
    if (!_supported) return '';
    try {
      return await _canalSante.invokeMethod<String>('etatEcriture') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// (Re)connexion depuis le profil : relance la demande d'accès même si
  /// elle a déjà été tentée dans cette session, puis relit les évaluations.
  /// Ainsi, si la personne vient d'ouvrir l'accès, Louane le voit sans
  /// redémarrer l'app.
  Future<void> reconnecter() async {
    if (!_supported) return;
    _authRequestedThisRun = false;
    await requestAuthorization();
    _resumeSante = null;
    _questionnaires = const [];
    _signauxBruts = const [];
    await resumeSanteMentale();
  }

  /// Relit Santé (questionnaires, état d'esprit, sommeil, lumière) sans
  /// rien demander : à appeler quand l'app revient au premier plan. Quelqu'un
  /// qui remplit le questionnaire dans Santé puis revient dans Quieto doit
  /// être vu tout de suite, pas à la prochaine session (Paul, 12/09). Les
  /// valeurs connues restent servies tant que la relecture n'a pas abouti.
  Future<void> rafraichir() async {
    if (!_supported) return;
    if (_lectureSante != null) return; // déjà en cours
    _lectureSante = _lireResumeSante();
    await _lectureSante;
  }

  // ── Évaluations de bien-être (questionnaires app Santé) ──

  /// Valeur instantanée pour les payloads Louane/parcours : ne déclenche
  /// rien, ne bloque JAMAIS. Vide tant que [resumeSanteMentale] n'a pas
  /// abouti (ou s'il n'y a rien à voir).
  String get resumeSanteCache => _resumeSante ?? '';

  /// Les questionnaires de bien-être lus dans Santé (vide tant que
  /// [resumeSanteMentale] n'a pas abouti). Instantané, jamais bloquant.
  List<QuestionnaireSante> get questionnaires => _questionnaires;

  /// Le test que la personne a fait en dernier, tel que Louane le nomme :
  /// anxiété seul, moral seul, ou le questionnaire complet. Null si rien de
  /// lisible (Android, iOS < 18, refus, aucun test, ou trop ancien). C'est
  /// lui qui décide si la carte « Louane analyse » peut s'afficher.
  TestSante? get testSante => testSanteDe(_questionnaires);

  /// Ce que la carte « Louane analyse » montre : le dernier test, et ses
  /// réponses telles qu'elle les a données. Null si rien de lisible.
  AnalyseSante? get analyseSante => AnalyseSante.depuis(_questionnaires);

  /// Ce que la feuille « Ce que Louane voit » affiche : chaque signal lu,
  /// en clair (titre + valeur), dans l'ordre du résumé envoyé à Louane.
  List<SignalSanteAffiche> get signaux => signauxPourAffichage(_signauxBruts);

  /// Lit (une fois par session) les dernières évaluations anxiété/humeur de
  /// l'app Santé via le canal natif et fabrique un petit texte français prêt
  /// pour Louane. '' si Android, iOS < 18, refus ou aucune évaluation.
  Future<String> resumeSanteMentale() {
    if (!_supported) return Future.value('');
    final connu = _resumeSante;
    if (connu != null) return Future.value(connu);
    return _lectureSante ??= _lireResumeSante();
  }

  Future<String> _lireResumeSante() async {
    try {
      final brut =
          await _canalSante.invokeListMethod<dynamic>('derniersScores') ??
              const [];
      _signauxBruts = brut;
      _questionnaires = questionnairesDepuis(brut);
      _resumeSante = formaterResumeSante(brut);
    } catch (e) {
      debugPrint('[Health] lecture évaluations échouée: $e');
      _signauxBruts = const [];
      _questionnaires = const [];
      _resumeSante = '';
    } finally {
      _lectureSante = null;
    }
    return _resumeSante ?? '';
  }

  /// Enregistre une période de pleine conscience [start] → [end] dans Santé.
  /// Apple ne retient que l'intervalle : la durée affichée = fin - début.
  Future<void> writeMindfulness(DateTime start, DateTime end) async {
    if (!_supported || !end.isAfter(start)) return;
    try {
      await _ensureConfigured();
      await _health.writeHealthData(
        value: 0,
        type: HealthDataType.MINDFULNESS,
        startTime: start,
        endTime: end,
      );
    } catch (e) {
      debugPrint('[Health] écriture pleine conscience échouée: $e');
    }
  }
}

// ── Questionnaires de bien-être : modèle, lecture, résumé pour Louane ──
// Fonctions pures (testées dans test/sante_resume_test.dart) : rien ici ne
// touche au canal natif.

/// Ce que la personne a fait dans Santé > Bien-être mental, tel que Louane
/// le nomme. Trois entrées dans l'app Santé, deux types sous le capot
/// (GAD-7 anxiété, PHQ-9 moral) : le « test de santé mentale » complet
/// enchaîne les deux et les enregistre à la même heure.
enum TestSante { anxiete, humeur, complet }

/// Un questionnaire noté lu dans Santé. [reponses] : 0 jamais · 1 plusieurs
/// jours · 2 plus de la moitié des jours · 3 presque tous les jours ;
/// 4 = « préfère ne pas répondre » (possible sur la 9e question du PHQ-9
/// seulement).
class QuestionnaireSante {
  final TestSante type; // anxiete ou humeur, jamais complet
  final String niveau; // faible / modere / eleve
  final int score;
  final List<int> reponses;
  final int jours; // ancienneté en jours (0 = aujourd'hui)
  final DateTime date;

  const QuestionnaireSante({
    required this.type,
    required this.niveau,
    required this.score,
    required this.reponses,
    required this.jours,
    required this.date,
  });
}

/// Au-delà, un questionnaire ne dit plus rien d'utile sur aujourd'hui.
const int kAncienneteMaxQuestionnaire = 90;

/// Deux questionnaires enregistrés à moins de cet écart = le questionnaire
/// complet de bien-être mental (Santé enchaîne les deux en un passage).
const Duration kEcartQuestionnaireComplet = Duration(minutes: 15);

/// Intitulés courts des questions, dans l'ordre officiel des deux
/// questionnaires (toujours « sur les deux dernières semaines »).
const List<String> kQuestionsAnxiete = [
  'nervosité, anxiété ou tension',
  'inquiétudes impossibles à arrêter',
  "s'inquiéter de tout et de rien",
  'mal à se détendre',
  'agitation, mal à rester en place',
  'irritabilité, facilement contrarié·e',
  "peur qu'il arrive quelque chose de grave",
];
const List<String> kQuestionsHumeur = [
  "peu d'intérêt ou de plaisir à faire les choses",
  'tristesse, découragement ou désespoir',
  'sommeil perturbé (trop peu ou trop)',
  "fatigue, manque d'énergie",
  'appétit perturbé (trop peu ou trop)',
  "mauvaise image de soi, sentiment d'échec",
  'mal à se concentrer',
  'ralentissement ou agitation que les autres remarquent',
  'idées noires (mieux vaudrait mourir, ou se faire du mal)',
];

/// Lit les cartes `anxiete` / `depression` renvoyées par le canal natif.
/// Tolérant : une carte incomplète ou trop ancienne est ignorée, jamais une
/// exception.
List<QuestionnaireSante> questionnairesDepuis(List<dynamic> brut) {
  final resultat = <QuestionnaireSante>[];
  for (final s in brut) {
    if (s is! Map) continue;
    final type = switch (s['type']) {
      'anxiete' => TestSante.anxiete,
      'depression' => TestSante.humeur,
      _ => null,
    };
    final niveau = s['niveau'];
    final score = s['score'];
    final reponses = s['reponses'];
    final horodatage = s['horodatage'];
    final jours = s['jours'];
    if (type == null ||
        niveau is! String ||
        score is! int ||
        reponses is! List ||
        horodatage is! num ||
        jours is! int) {
      continue;
    }
    if (jours > kAncienneteMaxQuestionnaire) continue;
    resultat.add(QuestionnaireSante(
      type: type,
      niveau: niveau,
      score: score,
      reponses: reponses.whereType<num>().map((r) => r.toInt()).toList(),
      jours: jours,
      date: DateTime.fromMillisecondsSinceEpoch((horodatage * 1000).round()),
    ));
  }
  return resultat;
}

/// Vrai si anxiété et moral ont été enregistrés ensemble : c'est le
/// questionnaire complet de bien-être mental.
bool estQuestionnaireComplet(List<QuestionnaireSante> qs) {
  QuestionnaireSante? anxiete;
  QuestionnaireSante? humeur;
  for (final q in qs) {
    if (q.type == TestSante.anxiete) anxiete = q;
    if (q.type == TestSante.humeur) humeur = q;
  }
  if (anxiete == null || humeur == null) return false;
  return anxiete.date.difference(humeur.date).abs() <=
      kEcartQuestionnaireComplet;
}

/// Le test le plus récent : complet si anxiété et moral ont été enregistrés
/// ensemble, sinon celui des deux qui est le plus frais.
TestSante? testSanteDe(List<QuestionnaireSante> qs) {
  if (qs.isEmpty) return null;
  if (estQuestionnaireComplet(qs)) return TestSante.complet;
  return qs.reduce((a, b) => a.date.isAfter(b.date) ? a : b).type;
}

String _quand(int jours) => jours == 0
    ? "aujourd'hui"
    : jours == 1
        ? 'hier'
        : 'il y a $jours jours';

/// Le résumé français prêt pour Louane, à partir des cartes brutes du canal
/// natif : les questionnaires en détail (lequel, quand, réponses une par
/// une), les autres signaux en niveau grossier. '' s'il n'y a rien à dire.
String formaterResumeSante(List<dynamic> scores) {
  final phrases = <String>[
    ..._phrasesQuestionnaires(questionnairesDepuis(scores)),
  ];
  const ressentis = {
    'agreable': 'plutôt agréable',
    'neutre': 'plutôt neutre',
    'desagreable': 'plutôt désagréable',
  };
  const nuits = {
    'court': 'plutôt courte',
    'correct': 'correcte',
    'bon': 'bonne',
  };
  for (final s in scores) {
    if (s is! Map) continue;
    final jours = s['jours'];
    if (jours is! int || jours > kAncienneteMaxQuestionnaire) continue;
    switch (s['type']) {
      case 'etat_esprit':
        final ressenti = ressentis[s['niveau']];
        final nb = s['nb'];
        if (ressenti == null || nb is! int) break;
        phrases.add("État d'esprit consigné dans Santé ($nb fois sur les "
            '7 derniers jours, dernier ${_quand(jours)}) : $ressenti.');
      case 'sommeil':
        final nuit = nuits[s['niveau']];
        final heures = s['heures'];
        if (nuit == null || heures is! num) break;
        phrases.add('Sommeil de la dernière nuit (Apple Santé) : '
            '~${heures}h, nuit $nuit.');
      case 'lumiere':
        final minutes = s['minutesParJour'];
        if (minutes is! int) break;
        phrases.add('Lumière du jour : ~$minutes min/jour en moyenne '
            'cette semaine.');
    }
  }
  return phrases.join(' ');
}

/// D'abord LEQUEL des trois tests elle a fait (Louane le nomme), puis le
/// détail de chaque questionnaire.
List<String> _phrasesQuestionnaires(List<QuestionnaireSante> qs) {
  if (qs.isEmpty) return const [];
  final phrases = <String>[];
  if (estQuestionnaireComplet(qs)) {
    final jours = qs.map((q) => q.jours).reduce((a, b) => a < b ? a : b);
    phrases.add('QUESTIONNAIRE SANTÉ : elle a fait le questionnaire COMPLET '
        'de bien-être mental (anxiété + moral enchaînés) ${_quand(jours)}.');
  } else {
    for (final q in qs) {
      phrases.add(q.type == TestSante.anxiete
          ? 'QUESTIONNAIRE SANTÉ : elle a fait le questionnaire ANXIÉTÉ seul '
              '(pas celui sur le moral) ${_quand(q.jours)}.'
          : 'QUESTIONNAIRE SANTÉ : elle a fait le questionnaire sur le MORAL '
              "seul (pas celui sur l'anxiété) ${_quand(q.jours)}.");
    }
  }
  for (final q in qs) {
    phrases.add(_detailQuestionnaire(q));
  }
  return phrases;
}

String _detailQuestionnaire(QuestionnaireSante q) {
  final anxiete = q.type == TestSante.anxiete;
  final libelles = anxiete ? kQuestionsAnxiete : kQuestionsHumeur;
  const niveaux = {'faible': 'faible', 'modere': 'modéré', 'eleve': 'élevé'};
  final niveau = niveaux[q.niveau] ?? q.niveau;
  final reponses = <String>[];
  for (var i = 0; i < libelles.length && i < q.reponses.length; i++) {
    final r = q.reponses[i];
    reponses.add('${libelles[i]} : ${r == 4 ? 'préfère ne pas répondre' : r}');
  }
  return '${anxiete ? 'Anxiété (GAD-7)' : 'Moral (PHQ-9)'} : niveau $niveau, '
      'score ${q.score}/${anxiete ? 21 : 27}. Réponses sur les 2 dernières '
      'semaines (0 jamais · 1 plusieurs jours · 2 plus de la moitié des '
      'jours · 3 presque tous les jours) : ${reponses.join(' ; ')}.';
}

// ── Le moment « Louane analyse » : contenu et chronologie ──

/// Les questions telles que l'app Santé les affiche : libellés EXACTS
/// d'Apple, relevés le 12/09/2026 dans la localisation française d'iOS 26.2
/// (MentalHealthUI.framework, clés GAD7_QUESTION_n / PHQ9_QUESTION_n). C'est
/// ce que la carte fait défiler sous les yeux de la personne, avec ses
/// réponses cochées : mot pour mot ce qu'elle a vu dans Santé.
const List<String> kQuestionsAnxieteSante = [
  'Un sentiment de nervosité, d’anxiété ou de tension',
  'Une incapacité à arrêter de s’inquiéter ou à contrôler ses inquiétudes',
  'Une inquiétude excessive à propos de différentes choses',
  'Des difficultés à se détendre',
  'Une agitation telle qu’il est difficile de tenir en place',
  'Une tendance à être facilement contrarié(e) ou irritable',
  'Un sentiment de peur comme si quelque chose de terrible risquait de se produire',
];
const List<String> kQuestionsHumeurSante = [
  'Peu d’intérêt ou de plaisir à faire les choses',
  'Être triste, déprimé(e) ou désespéré(e)',
  'Difficultés à s’endormir ou à rester endormi(e), ou dormir trop',
  'Se sentir fatigué(e) ou manquer d’énergie',
  'Avoir peu d’appétit ou manger trop',
  'Avoir une mauvaise opinion de soi-même, ou avoir le sentiment d’être nul(le), ou d’avoir déçu sa famille ou s’être déçu(e) soi-même',
  'Avoir du mal à se concentrer, par exemple, pour lire le journal ou regarder la télévision',
  'Bouger ou parler si lentement que les autres auraient pu le remarquer. Ou au contraire, être si agité(e) que vous avez eu du mal à tenir en place par rapport à d’habitude',
  'Penser qu’il vaudrait mieux mourir ou envisager de vous faire du mal d’une manière ou d’une autre',
];

/// Les choix proposés par Santé, dans l'ordre (index = valeur 0-3), libellés
/// exacts d'Apple. La 9e question du PHQ-9 est « facultative » dans Santé :
/// laissée sans réponse, elle vaut 4 (« Je préfère ne pas répondre »).
const List<String> kChoixQuestionnaireSante = [
  'Jamais',
  'Plusieurs jours',
  'Plus de la moitié du temps',
  'Presque tous les jours',
];
const String kChoixPasRepondre = 'Je préfère ne pas répondre';

/// Une question de la carte : son numéro dans le test tel que Santé le
/// compte, son libellé Apple, et la réponse donnée.
class QuestionAnalyse {
  final int numero; // 1..total
  final int total;
  final String libelle;
  final int reponse; // 0-3, 4 = laissée sans réponse (facultative)

  /// Question facultative dans Santé (la 9e du PHQ-9) : affichée
  /// « (facultatif) », et sans coche si elle a été laissée vide.
  final bool avecChoixPasRepondre;

  const QuestionAnalyse({
    required this.numero,
    required this.total,
    required this.libelle,
    required this.reponse,
    this.avecChoixPasRepondre = false,
  });

  /// Toujours quatre lignes de choix, comme dans Santé.
  int get nbChoix => 4;
}

/// Ce que la carte « Louane analyse » montre et combien de temps elle dure.
/// La chronologie vit ici (couche données) parce que le fil de conversation
/// attend exactement ce temps-là avant de taper les bulles.
class AnalyseSante {
  final TestSante test;

  /// Un questionnaire (anxiété ou moral), ou les deux dans l'ordre de Santé
  /// (anxiété puis moral) pour le questionnaire complet.
  final List<QuestionnaireSante> questionnaires;

  const AnalyseSante({required this.test, required this.questionnaires});

  /// Le dernier test lu dans Santé, ou null s'il n'y a rien à montrer.
  static AnalyseSante? depuis(List<QuestionnaireSante> qs) {
    final test = testSanteDe(qs);
    if (test == null) return null;
    if (test == TestSante.complet) {
      return AnalyseSante(test: test, questionnaires: [
        qs.lastWhere((q) => q.type == TestSante.anxiete),
        qs.lastWhere((q) => q.type == TestSante.humeur),
      ]);
    }
    return AnalyseSante(
      test: test,
      questionnaires: [qs.reduce((a, b) => a.date.isAfter(b.date) ? a : b)],
    );
  }

  /// Toutes les questions à faire défiler, numérotées comme dans Santé
  /// (le complet compte de 1 à 16, anxiété d'abord).
  List<QuestionAnalyse> get questions {
    final total = questionnaires.fold<int>(
        0, (n, q) => n + (q.type == TestSante.anxiete ? 7 : 9));
    final resultat = <QuestionAnalyse>[];
    for (final q in questionnaires) {
      final anxiete = q.type == TestSante.anxiete;
      final libelles = anxiete ? kQuestionsAnxieteSante : kQuestionsHumeurSante;
      for (var i = 0; i < libelles.length; i++) {
        resultat.add(QuestionAnalyse(
          numero: resultat.length + 1,
          total: total,
          libelle: libelles[i],
          reponse: i < q.reponses.length ? q.reponses[i].clamp(0, 4) : 0,
          avecChoixPasRepondre: !anxiete && i == 8,
        ));
      }
    }
    return resultat;
  }

  // Chronologie : un temps de pose sur le titre, puis chaque question défile
  // et se coche, puis deux étapes courtes où Louane relie et prépare.
  static const Duration dureeIntro = Duration(milliseconds: 900);
  static const Duration dureeParQuestion = Duration(milliseconds: 520);
  static const Duration dureeLiens = Duration(milliseconds: 2000);
  static const Duration dureeSynthese = Duration(milliseconds: 1700);

  Duration get dureeLecture => dureeIntro + dureeParQuestion * questions.length;

  /// Durée totale du moment : le fil attend ce temps avant les bulles.
  Duration get duree => dureeLecture + dureeLiens + dureeSynthese;
}

// ── Affichage à la personne : « Ce que Louane voit » ──

/// Un signal Santé tel que la feuille du chat le montre.
class SignalSanteAffiche {
  final String titre;
  final String valeur;
  const SignalSanteAffiche(this.titre, this.valeur);
}

String _majuscule(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

/// Les mêmes signaux que [formaterResumeSante], mais pour les yeux de la
/// personne : questionnaires (lequel, quand, niveau), puis état d'esprit,
/// sommeil, lumière. Vide s'il n'y a rien.
List<SignalSanteAffiche> signauxPourAffichage(List<dynamic> brut) {
  final resultat = <SignalSanteAffiche>[];
  final qs = questionnairesDepuis(brut);
  const niveaux = {
    'faible': 'niveau faible',
    'modere': 'niveau modéré',
    'eleve': 'niveau élevé',
  };
  final complet = estQuestionnaireComplet(qs);
  for (final q in qs) {
    final anxiete = q.type == TestSante.anxiete;
    final titre = complet
        ? (anxiete ? 'Bien-être mental · anxiété' : 'Bien-être mental · dépression')
        : (anxiete ? "Questionnaire sur l'anxiété" : 'Questionnaire sur la dépression');
    resultat.add(SignalSanteAffiche(
      titre,
      '${_majuscule(_quand(q.jours))} · ${niveaux[q.niveau] ?? q.niveau}',
    ));
  }
  const ressentis = {
    'agreable': 'Plutôt agréable',
    'neutre': 'Plutôt neutre',
    'desagreable': 'Plutôt désagréable',
  };
  const nuits = {'court': 'nuit courte', 'correct': 'nuit correcte', 'bon': 'bonne nuit'};
  for (final s in brut) {
    if (s is! Map) continue;
    final jours = s['jours'];
    if (jours is! int || jours > kAncienneteMaxQuestionnaire) continue;
    switch (s['type']) {
      case 'etat_esprit':
        final ressenti = ressentis[s['niveau']];
        final nb = s['nb'];
        if (ressenti == null || nb is! int) break;
        resultat.add(SignalSanteAffiche(
          "État d'esprit",
          '$ressenti · $nb fois cette semaine',
        ));
      case 'sommeil':
        final nuit = nuits[s['niveau']];
        final heures = s['heures'];
        if (nuit == null || heures is! num) break;
        resultat.add(SignalSanteAffiche(
          'Sommeil',
          '~${heures.toString().replaceAll('.', ',')} h · $nuit',
        ));
      case 'lumiere':
        final minutes = s['minutesParJour'];
        if (minutes is! int) break;
        resultat.add(SignalSanteAffiche('Lumière du jour', '~$minutes min par jour'));
    }
  }
  return resultat;
}
