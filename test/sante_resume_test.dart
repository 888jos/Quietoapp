import 'package:flutter_test/flutter_test.dart';
import 'package:quieto/core/services/health_service.dart';

/// Les trois tests de Santé > Bien-être mental, tels que Louane doit les
/// distinguer : anxiété seul, moral seul, ou le questionnaire complet (les
/// deux enregistrés ensemble). Et le résumé qu'elle reçoit.
void main() {
  final maintenant = DateTime(2026, 9, 11, 20, 0);
  double epoch(DateTime d) => d.millisecondsSinceEpoch / 1000;

  Map<String, dynamic> anxiete({
    DateTime? date,
    int jours = 2,
    List<int> reponses = const [2, 2, 1, 3, 0, 1, 2],
  }) =>
      {
        'type': 'anxiete',
        'niveau': 'modere',
        'score': reponses.fold(0, (a, b) => a + b),
        'reponses': reponses,
        'horodatage': epoch(date ?? maintenant.subtract(Duration(days: jours))),
        'jours': jours,
      };

  Map<String, dynamic> humeur({
    DateTime? date,
    int jours = 2,
    List<int> reponses = const [1, 1, 2, 2, 0, 1, 1, 0, 4],
  }) =>
      {
        'type': 'depression',
        'niveau': 'faible',
        'score': reponses.where((r) => r != 4).fold(0, (a, b) => a + b),
        'reponses': reponses,
        'horodatage': epoch(date ?? maintenant.subtract(Duration(days: jours))),
        'jours': jours,
      };

  group('testSanteDe : lequel des trois tests', () {
    test('anxiété seul', () {
      expect(testSanteDe(questionnairesDepuis([anxiete()])), TestSante.anxiete);
    });

    test('moral seul', () {
      expect(testSanteDe(questionnairesDepuis([humeur()])), TestSante.humeur);
    });

    test('les deux à la même heure = questionnaire complet', () {
      final d = maintenant.subtract(const Duration(days: 1));
      final qs = questionnairesDepuis([
        anxiete(date: d, jours: 1),
        humeur(date: d.add(const Duration(minutes: 4)), jours: 1),
      ]);
      expect(estQuestionnaireComplet(qs), isTrue);
      expect(testSanteDe(qs), TestSante.complet);
    });

    test('les deux à des jours différents = le plus récent, pas complet', () {
      final qs = questionnairesDepuis([
        anxiete(jours: 20),
        humeur(jours: 3),
      ]);
      expect(estQuestionnaireComplet(qs), isFalse);
      expect(testSanteDe(qs), TestSante.humeur);
    });

    test('rien, ou trop ancien → null', () {
      expect(testSanteDe(questionnairesDepuis(const [])), isNull);
      expect(testSanteDe(questionnairesDepuis([anxiete(jours: 120)])), isNull);
    });

    test('une carte sans réponses (vieux natif) est ignorée sans planter', () {
      final carte = anxiete()..remove('reponses');
      expect(questionnairesDepuis([carte]), isEmpty);
      expect(formaterResumeSante([carte]), '');
    });
  });

  group('formaterResumeSante : ce que Louane lit', () {
    test('anxiété seul : nommé, daté, réponses une par une, score sur 21', () {
      final r = formaterResumeSante([anxiete()]);
      expect(r, contains('questionnaire ANXIÉTÉ seul'));
      expect(r, contains('il y a 2 jours'));
      expect(r, contains('Anxiété (GAD-7) : niveau modéré, score 11/21'));
      expect(r, contains('mal à se détendre : 3'));
      expect(r, isNot(contains('MORAL seul')));
      expect(r, isNot(contains('COMPLET')));
    });

    test('moral seul : « préfère ne pas répondre » sur la 9e question', () {
      final r = formaterResumeSante([humeur(jours: 0)]);
      expect(r, contains('questionnaire sur le MORAL seul'));
      expect(r, contains("aujourd'hui"));
      expect(r, contains('Moral (PHQ-9) : niveau faible, score 8/27'));
      expect(r, contains('idées noires (mieux vaudrait mourir, ou se faire du '
          'mal) : préfère ne pas répondre'));
    });

    test('complet : une seule phrase d\'annonce, puis les deux détails', () {
      final d = maintenant.subtract(const Duration(days: 1));
      final r = formaterResumeSante([
        anxiete(date: d, jours: 1),
        humeur(date: d, jours: 1),
      ]);
      expect(r, contains('questionnaire COMPLET de bien-être mental'));
      expect(r, contains('hier'));
      expect('COMPLET'.allMatches(r).length, 1);
      expect(r, contains('Anxiété (GAD-7)'));
      expect(r, contains('Moral (PHQ-9)'));
      expect(r.length, lessThan(1800)); // BORNES.sante côté serveur
    });

    test('AnalyseSante : les questions défilent numérotées comme dans Santé',
        () {
      final d = maintenant.subtract(const Duration(days: 1));
      final complet = AnalyseSante.depuis(questionnairesDepuis([
        anxiete(date: d, jours: 1),
        humeur(date: d, jours: 1),
      ]))!;
      expect(complet.test, TestSante.complet);
      expect(complet.questions.length, 16);
      expect(complet.questions.first.numero, 1);
      expect(complet.questions.first.total, 16);
      expect(complet.questions.last.numero, 16);
      expect(complet.questions.last.avecChoixPasRepondre, isTrue);
      expect(complet.questions.last.reponse, 4);
      expect(complet.questions[3].reponse, 3); // mal à se détendre
      expect(complet.duree,
          AnalyseSante.dureeIntro + AnalyseSante.dureeParQuestion * 16 +
              AnalyseSante.dureeLiens + AnalyseSante.dureeSynthese);

      final seul = AnalyseSante.depuis(questionnairesDepuis([anxiete()]))!;
      expect(seul.test, TestSante.anxiete);
      expect(seul.questions.length, 7);
      expect(seul.questions.last.total, 7);
      expect(seul.questions.any((q) => q.avecChoixPasRepondre), isFalse);

      expect(AnalyseSante.depuis(const []), isNull);
    });

    test('signauxPourAffichage : ce que la feuille « Ce que Louane voit » '
        'montre', () {
      final lignes = signauxPourAffichage([
        anxiete(),
        {'type': 'sommeil', 'niveau': 'court', 'heures': 5.5, 'jours': 0},
        {'type': 'etat_esprit', 'niveau': 'neutre', 'nb': 3, 'jours': 1},
        {'type': 'lumiere', 'minutesParJour': 40, 'jours': 0},
      ]);
      expect(lignes.map((l) => l.titre).toList(), [
        "Questionnaire sur l'anxiété",
        'Sommeil',
        "État d'esprit",
        'Lumière du jour',
      ]);
      expect(lignes.first.valeur, 'Il y a 2 jours · niveau modéré');
      expect(lignes[1].valeur, '~5,5 h · nuit courte');
      expect(lignes[2].valeur, 'Plutôt neutre · 3 fois cette semaine');
      expect(lignes[3].valeur, '~40 min par jour');
      expect(signauxPourAffichage(const []), isEmpty);

      final d = maintenant.subtract(const Duration(days: 1));
      final complet = signauxPourAffichage([
        anxiete(date: d, jours: 1),
        humeur(date: d, jours: 1),
      ]);
      expect(complet.map((l) => l.titre).toList(), [
        'Bien-être mental · anxiété',
        'Bien-être mental · dépression',
      ]);
    });

    test('les autres signaux restent en niveau grossier', () {
      final r = formaterResumeSante([
        anxiete(),
        {'type': 'sommeil', 'niveau': 'court', 'heures': 5.5, 'jours': 0},
        {'type': 'etat_esprit', 'niveau': 'neutre', 'nb': 3, 'jours': 1},
        {'type': 'lumiere', 'minutesParJour': 40, 'jours': 0},
      ]);
      expect(r, contains('~5.5h, nuit plutôt courte'));
      expect(r, contains('plutôt neutre'));
      expect(r, contains('~40 min/jour'));
    });
  });
}
