/// Programme de la semaine affiché sur l'écran « Voici ton programme ».
///
/// Même squelette pour tout le monde (J1 première séance → J7 bilan),
/// mais les 5 jours du milieu sont tissés à partir de TOUS les objectifs
/// cochés au quiz : l'objectif n°1 (q1) reste le fil rouge (il nomme le
/// programme et choisit la séance du J7), et chaque autre objectif coché
/// obtient son ou ses jours, annoncés explicitement (« Tu veux aussi
/// mieux dormir. ... ») pour que la personne voie que toutes ses réponses
/// comptent. Jamais de séance d'un objectif non coché, jamais deux fois
/// la même séance dans la semaine. La durée (q_minutes), le moment (q4)
/// et l'expérience (q2) ajustent le reste. Tous les titres de séances
/// cités entre « » existent vraiment dans explore_repository.dart :
/// ne pas inventer de titre ici.
library;

class ProgramDay {
  /// La séance du jour (titre exact du catalogue + durée).
  final String title;

  /// Pourquoi ça fait du bien, en une phrase courte.
  final String why;

  const ProgramDay({required this.title, required this.why});
}

/// Phrase du moment choisi, injectée dans certains textes.
String _momentPhrase(String q4) {
  if (q4.contains('matin')) return 'le matin au réveil';
  if (q4.contains('journée')) return 'dans ta journée';
  if (q4.contains('soir')) return 'le soir';
  return 'au moment qui t\'arrange';
}

/// Reformulation « tu veux aussi … » de chaque objectif, utilisée dans
/// le résumé du profil et pour annoncer les jours des objectifs
/// secondaires du programme.
const _alsoFragments = <String, String>{
  'Apaiser mon stress': 'relâcher la pression',
  'Mieux dormir': 'mieux dormir',
  'Calmer mon anxiété': 'apaiser l\'anxiété',
  'Me reconcentrer': 'te reconcentrer',
  'Prendre soin de moi': 'prendre soin de toi',
};

/// Résumé du profil, REFORMULÉ à partir des réponses (jamais de
/// copier-coller des intitulés du quiz : la personne doit sentir
/// qu'on a compris, pas qu'on lui recrache ses cases cochées).
/// TOUS les objectifs cochés sont cités, pas seulement le premier.
/// Écriture : phrases courtes, une idée par phrase, pas de « et »
/// en cascade.
String buildProfileSummary({
  required String priority,
  required List<String> goals,
  required String minutes,
  required String moment,
  required bool experienced,
}) {
  final problem = switch (priority) {
    'Apaiser mon stress' => 'Le stress prend trop de place dans tes journées.',
    'Mieux dormir' => 'Tes nuits ne te reposent pas vraiment.',
    'Calmer mon anxiété' => 'L\'anxiété tourne en fond, elle te fatigue.',
    'Me reconcentrer' => 'Ton attention part dans tous les sens.',
    'Prendre soin de moi' => 'Tu veux un vrai moment rien que pour toi.',
    _ => 'Tu veux retrouver un peu de calme.',
  };

  const nouns = <String, String>{
    'Apaiser mon stress': 'le stress',
    'Mieux dormir': 'ton sommeil',
    'Calmer mon anxiété': 'l\'anxiété',
    'Me reconcentrer': 'ta concentration',
    'Prendre soin de moi': 'les moments rien que pour toi',
  };
  final others = [
    for (final g in goals)
      if (g != priority && nouns.containsKey(g)) nouns[g]!,
  ];
  final also = switch (others.length) {
    0 => '',
    1 => ' Sans oublier ${others.first}.',
    _ => ' Sans oublier le reste : ${others.join(', ')}.',
  };

  final pace = experienced
      ? 'On approfondit à ton rythme'
      : 'On y va en douceur';

  final dose = switch (minutes) {
    'Moins de 5 minutes' => 'quelques minutes',
    'Environ 10 minutes' => 'une dizaine de minutes',
    'Plus de 15 minutes' => 'un bon quart d\'heure',
    _ => 'quelques minutes',
  };

  return '$problem$also $pace, avec $dose ${_momentPhrase(moment)}. '
      'De quoi sentir la différence dès les premiers jours. '
      'Louane, ta compagne de route, te suit tout du long : '
      'tu peux lui parler à tout moment.';
}

/// Les 5 jours « types » de chaque objectif, dans l'ordre de préférence.
/// Le tissage pioche dedans en évitant les doublons entre objectifs.
List<ProgramDay> _goalPool(
  String goal, {
  required bool short,
  required bool long,
  required String moment,
}) {
  switch (goal) {
    case 'Mieux dormir':
      return [
        const ProgramDay(
          title: '« Rituel pré-sommeil » (7 min)',
          why:
              'On crée le signal qui dit à ton corps que la journée '
              'est finie.',
        ),
        const ProgramDay(
          title: '« Cohérence cardiaque » (4 min)',
          why:
              'Le cœur ralentit, le corps comprend, le sommeil vient '
              'plus vite.',
        ),
        const ProgramDay(
          title: '« Visualisation apaisante » (7 min)',
          why:
              'Tu emmènes ton esprit ailleurs : des images douces qui '
              'préparent la nuit.',
        ),
        short
            ? const ProgramDay(
                title: '« Juste avant de dormir » (3 min)',
                why: 'Trois minutes au lit, juste avant d\'éteindre.',
              )
            : const ProgramDay(
                title: '« Détente du soir » (13 min)',
                why:
                    'La grande séance du soir : on lâche la journée '
                    'morceau par morceau.',
              ),
        const ProgramDay(
          title: '« Entre deux mondes » (7 min)',
          why: 'La séance qui t\'accompagne jusqu\'au bord du sommeil.',
        ),
      ];

    case 'Calmer mon anxiété':
      return [
        const ProgramDay(
          title: '« Respiration 4-7-8 » (5 min)',
          why: 'Ton frein d\'urgence : à ressortir dès que ça monte.',
        ),
        const ProgramDay(
          title: '« Ancrage » (6 min)',
          why:
              'Quand les pensées s\'emballent, on revient au concret : '
              'le corps, le sol, le souffle.',
        ),
        const ProgramDay(
          title: '« Souffle apaisant » (8 min)',
          why:
              'Le souffle est ton allié le plus fiable contre '
              'l\'anxiété : on l\'entraîne.',
        ),
        const ProgramDay(
          title: '« Quand le stress prend le dessus » (7 min)',
          why:
              'On désamorce la tension avant qu\'elle ne nourrisse '
              'l\'anxiété.',
        ),
        long
            ? const ProgramDay(
                title: '« De l\'anxiété au sourire » (14 min)',
                why:
                    'La grande traversée de la semaine : on apprivoise '
                    'l\'anxiété au lieu de la fuir.',
              )
            : const ProgramDay(
                title: '« Peur et courage » (7 min)',
                why:
                    'On regarde la peur en face, avec douceur : elle '
                    'perd du terrain.',
              ),
      ];

    case 'Me reconcentrer':
      return [
        const ProgramDay(
          title: '« Cohérence cardiaque » (4 min)',
          why:
              'Un esprit posé se concentre mieux : on commence par '
              'calmer le fond.',
        ),
        const ProgramDay(
          title: '« Débrancher quand tout crie » (8 min)',
          why: 'Moins de bruit mental, plus de place pour ce qui compte.',
        ),
        const ProgramDay(
          title: '« Ancrage » (6 min)',
          why:
              'Revenir au corps pour ramener l\'esprit : la base de la '
              'concentration.',
        ),
        const ProgramDay(
          title: '« Pause info » (7 min)',
          why:
              'Tu reprends la main sur les écrans et les notifications '
              'qui te happent.',
        ),
        const ProgramDay(
          title: '« Observer sans juger » (7 min)',
          why:
              'Le muscle de l\'attention : remarquer, revenir, '
              'recommencer.',
        ),
      ];

    case 'Prendre soin de moi':
      return [
        short
            ? const ProgramDay(
                title: '« Cohérence cardiaque » (4 min)',
                why:
                    'On commence par le souffle : le plus simple '
                    'des soins.',
              )
            : const ProgramDay(
                title: '« Souffle apaisant » (8 min)',
                why:
                    'On commence par le souffle : le plus simple '
                    'des soins.',
              ),
        const ProgramDay(
          title: '« Apprendre à s\'aimer » (8 min)',
          why:
              'Le cœur de ta semaine : un peu de bienveillance '
              'tournée vers toi.',
        ),
        const ProgramDay(
          title: '« Observer sans juger » (7 min)',
          why:
              'Apprendre à te regarder avec plus de douceur, sans te '
              'juger.',
        ),
        const ProgramDay(
          title: '« Joie et énergie » (9 min)',
          why:
              'Prendre soin de soi, c\'est aussi recharger, pas '
              'seulement réparer.',
        ),
        const ProgramDay(
          title: '« L\'amour » (8 min)',
          why: 'On élargit la douceur : vers toi, puis vers les autres.',
        ),
      ];

    // « Apaiser mon stress » et défaut (aucune priorité enregistrée).
    default:
      return [
        ProgramDay(
          title: '« Cohérence cardiaque » (4 min)',
          why:
              'L\'outil le plus rapide pour faire redescendre la '
              'pression, ${_momentPhrase(moment)}.',
        ),
        const ProgramDay(
          title: '« Quand le stress prend le dessus » (7 min)',
          why:
              'Ta première séance ciblée : on s\'attaque à ce qui te '
              'pèse vraiment.',
        ),
        const ProgramDay(
          title: '« Souffle apaisant » (8 min)',
          why:
              'Ton souffle devient ton outil anti-tension, disponible '
              'partout.',
        ),
        const ProgramDay(
          title: '« Ancrage » (6 min)',
          why: 'Un réflexe à ressortir partout quand la tension monte.',
        ),
        short
            ? const ProgramDay(
                title: '« Respiration 4-7-8 » (5 min)',
                why:
                    'Un enchaînement court qui détend le corps en '
                    'profondeur.',
              )
            : const ProgramDay(
                title: '« Relâche » (9 min)',
                why:
                    'Le corps garde le stress. Cette séance le fait '
                    'lâcher.',
              ),
      ];
  }
}

/// Construit les 7 jours du programme en tissant TOUS les objectifs cochés.
List<ProgramDay> buildWeeklyProgram({
  required String priority,
  required List<String> goals,
  required String minutes,
  required String moment,
  required bool experienced,
}) {
  final short = minutes == 'Moins de 5 minutes';
  final long = minutes == 'Plus de 15 minutes';

  // J1 : la séance d'ouverture pour tout le monde, explication
  // adaptée au niveau.
  final day1 = experienced
      ? const ProgramDay(
          title: '« Ma première méditation » (6 min)',
          why:
              'Ça commence maintenant : 30 secondes de respiration juste '
              'après, puis la séance d\'ouverture pour poser le cadre, '
              'même si tu pratiques déjà.',
        )
      : const ProgramDay(
          title: '« Ma première méditation » (6 min)',
          why:
              'Ça commence maintenant : 30 secondes de respiration juste '
              'après, puis ta toute première séance, en douceur.',
        );

  // J7 : bilan, séance selon l'objectif n°1.
  const day7Why =
      'Tu mesures le chemin parcouru sur la semaine et tu installes '
      'l\'habitude.';
  final day7 = priority == 'Mieux dormir'
      ? const ProgramDay(
          title: '« Plongée dans le silence » (6 min)',
          why: day7Why,
        )
      : const ProgramDay(title: '« Le moment présent » (6 min)', why: day7Why);

  // Objectifs dans l'ordre : priorité d'abord, puis l'ordre du quiz.
  final ordered = <String>[
    if (priority.isNotEmpty) priority,
    ...goals.where((g) => g != priority),
  ];
  if (ordered.isEmpty) ordered.add('Apaiser mon stress');

  // Répartition des 5 jours du milieu : la priorité garde la plus
  // grosse part, chaque autre objectif a AU MOINS un jour à lui.
  final counts = switch (ordered.length) {
    1 => [5],
    2 => [3, 2],
    3 => [2, 2, 1],
    4 => [2, 1, 1, 1],
    _ => [1, 1, 1, 1, 1],
  };

  // Ordre des jours : on alterne les objectifs (priorité, autre,
  // priorité…) pour que la semaine se sente tissée, pas découpée en blocs.
  final order = <int>[];
  final left = [...counts];
  while (order.length < 5) {
    for (var i = 0; i < left.length && order.length < 5; i++) {
      if (left[i] > 0) {
        order.add(i);
        left[i]--;
      }
    }
  }

  final pools = [
    for (final g in ordered)
      _goalPool(g, short: short, long: long, moment: moment),
  ];
  // Une même séance ne revient jamais deux fois dans la semaine
  // (les objectifs partagent certaines séances).
  final used = <String>{day1.title, day7.title};

  ProgramDay? takeFrom(int i) {
    for (final d in pools[i]) {
      if (used.add(d.title)) return d;
    }
    return null;
  }

  final middle = <ProgramDay>[];
  final announced = List<bool>.filled(ordered.length, false);
  for (final i in order) {
    var day = takeFrom(i);
    // Réserve épuisée (objectifs très proches) : on pioche chez un autre.
    for (var j = 0; day == null && j < pools.length; j++) {
      if (j != i) day = takeFrom(j);
    }
    if (day == null) break;
    // Le premier jour de chaque objectif secondaire est annoncé
    // explicitement : la personne voit que sa réponse a compté.
    if (i != 0 && !announced[i] && _alsoFragments.containsKey(ordered[i])) {
      day = ProgramDay(
        title: day.title,
        why: 'Tu veux aussi ${_alsoFragments[ordered[i]]}. ${day.why}',
      );
    }
    announced[i] = true;
    middle.add(day);
  }

  return [day1, ...middle, day7];
}
