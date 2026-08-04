import 'package:flutter_test/flutter_test.dart';
import 'package:quieto/core/models/parcours_model.dart';
import 'package:quieto/features/parcours/presentation/parcours_creation_page.dart';
import 'package:quieto/features/parcours/presentation/parcours_page.dart';
import 'package:quieto/features/parcours/presentation/widgets/carte_partage_parcours.dart';

/// Le programme 7 jours créé par Louane : sérialisation, avancement des
/// jours (1 jour par jour calendaire) et règles de style des textes en dur.
void main() {
  ParcoursModel parcoursTest() => ParcoursModel(
        titre: '7 jours pour retrouver ton sommeil',
        sousTitre: 'Une semaine douce.',
        creeLe: '2026-07-23T10:00:00.000',
        jours: [
          for (var j = 1; j <= 7; j++)
            ParcoursJour(
              jour: j,
              sessionId: 'seance_$j',
              titreSeance: 'Séance $j',
              dureeMin: j + 2,
              premium: j > 1,
              motDeLouane: 'Un mot pour le jour $j.',
            ),
        ],
      );

  test('toJson/fromJson : aller-retour sans perte', () {
    final avant = parcoursTest()
        .marquerJourTermine(1, DateTime(2026, 7, 23, 21, 30))
        .avecBilan('Pareil');
    final apres = ParcoursModel.fromJson(avant.toJson());

    expect(apres.titre, avant.titre);
    expect(apres.jours, hasLength(7));
    expect(apres.jours[2].sessionId, 'seance_3');
    expect(apres.jours[2].premium, isTrue);
    expect(apres.joursTermines, avant.joursTermines);
    expect(apres.dernierJourTermineLe, '2026-07-23');
    expect(apres.bilanFait, isTrue);
    expect(apres.bilanRessenti, 'Pareil');
  });

  test('jourCourant avance avec les jours terminés, plafonné à 7', () {
    var p = parcoursTest();
    expect(p.jourCourant, 1);

    p = p.marquerJourTermine(1, DateTime(2026, 7, 23, 21));
    expect(p.jourCourant, 2);

    for (var j = 2; j <= 7; j++) {
      p = p.marquerJourTermine(j, DateTime(2026, 7, 23 + j));
    }
    expect(p.jourCourant, 7);
    expect(p.tousJoursTermines, isTrue);
    expect(p.termine, isFalse); // pas encore de bilan
    expect(p.avecBilan('Apaisé(e)').termine, isTrue);
  });

  test('rythme : le jour suivant se débloque le lendemain, pas le soir même',
      () {
    final p = parcoursTest().marquerJourTermine(1, DateTime(2026, 7, 23, 21));

    // Le soir même : J1 rejouable (terminé), J2 verrouillé, J3 aussi.
    expect(p.jourDebloque(1, '2026-07-23'), isTrue);
    expect(p.jourDebloque(2, '2026-07-23'), isFalse);
    expect(p.jourDebloque(3, '2026-07-23'), isFalse);
    expect(p.seanceDuJourFaite('2026-07-23'), isTrue);

    // Le lendemain : J2 (jour courant) débloqué, J3 toujours pas.
    expect(p.jourDebloque(2, '2026-07-24'), isTrue);
    expect(p.jourDebloque(3, '2026-07-24'), isFalse);
    expect(p.seanceDuJourFaite('2026-07-24'), isFalse);
  });

  test('pourServeur : l\'état résumé que Louane reçoit', () {
    final p = parcoursTest().marquerJourTermine(1, DateTime(2026, 7, 23, 21));

    final soirMeme = p.pourServeur('2026-07-23');
    expect(soirMeme['actif'], isTrue);
    expect(soirMeme['jour'], 2);
    expect(soirMeme['seanceDuJourFaite'], isTrue);

    final lendemain = p.pourServeur('2026-07-24');
    expect(lendemain['seanceDuJourFaite'], isFalse);

    final fini = parcoursTest().avecBilan('Pareil').pourServeur('2026-07-25');
    expect(fini['actif'], isFalse);
    expect(fini['termine'], isTrue);
  });

  test('textes en dur : majuscule initiale, pas de tiret long, pas d\'emoji',
      () {
    final textes = [
      ...kEtapesCreationParcours,
      ...kRessentisBilan,
      ...kEncouragementsParcours,
      kSignatureCartePartage,
    ];
    for (final t in textes) {
      expect(t.trim(), isNotEmpty);
      expect(t.contains('—'), isFalse, reason: 'tiret long dans « $t »');
      expect(t.contains('–'), isFalse, reason: 'tiret dans « $t »');
      expect(t[0], t[0].toUpperCase(), reason: 'minuscule initiale : « $t »');
    }
  });
}
