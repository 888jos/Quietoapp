import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quieto/core/config/app_constants.dart';
import 'package:quieto/core/services/storage_service.dart';
import 'package:quieto/core/services/vigie_service.dart';
import 'package:quieto/features/louane/data/louane_repository.dart';
import 'package:quieto/features/louane/louane_providers.dart';

/// L'accueil de Louane : à la toute première ouverture elle se présente
/// (trois bulles tapées en direct) ; aux sessions suivantes, « Hey Paul »
/// puis une phrase adaptée à l'heure.
void main() {
  Future<LouaneChatNotifier> creerNotifier() async {
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final vigie = VigieService(prefs);
    final repo = LouaneRepository(storage, vigie, () => false);
    return LouaneChatNotifier(repo, vigie, () => false, storage);
  }

  test('première ouverture : frappe puis les trois bulles de présentation',
      () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = await creerNotifier();

    expect(notifier.state.messages, isEmpty);

    final sequence = notifier.jouerIntro();

    // Pendant la frappe (après le silence initial), l'indicateur est visible.
    await Future.delayed(const Duration(milliseconds: 800));
    expect(notifier.state.louaneEcrit, isTrue);

    await sequence;
    expect(notifier.state.messages, hasLength(3));
    expect(notifier.state.messages.every((m) => m.estLouane), isTrue);
    expect(notifier.state.messages[1].texte, "Moi c'est Louane");
    expect(notifier.state.messages[2].texte, contains("t'amène"));
    expect(notifier.state.louaneEcrit, isFalse);

    // L'intro est marquée comme vue pour les prochains lancements.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppConstants.prefLouaneIntroVariante), isNotNull);
  });

  test('la question d\'ouverture reformule l\'objectif de l\'onboarding',
      () async {
    // La personne a dit dans l'onboarding pourquoi elle est là : Louane ne
    // redemande pas, elle reformule et fait confirmer.
    SharedPreferences.setMockInitialValues({
      AppConstants.prefOnboardingAnswers:
          jsonEncode({'goals': 'Apaiser mon stress'}),
    });
    final notifier = await creerNotifier();
    await notifier.jouerIntro();

    expect(notifier.state.messages, hasLength(3));
    expect(notifier.state.messages[2].texte,
        contains('surtout là pour apaiser ton stress'));
    expect(notifier.state.messages[2].texte, contains("c'est bien ça ?"));
  });

  test('tout coché : Louane le dit et rend la main, en deux bulles', () async {
    // Les cinq réponses cochées : les réciter ferait inventaire. Louane
    // l'avoue et repose la question — la seule variante en deux bulles.
    SharedPreferences.setMockInitialValues({
      AppConstants.prefOnboardingAnswers: jsonEncode({
        'goals': 'Apaiser mon stress|Mieux dormir|Calmer mon anxiété|'
            'Me reconcentrer|Prendre soin de moi',
      }),
    });
    final notifier = await creerNotifier();
    await notifier.jouerIntro();

    expect(notifier.state.messages, hasLength(4));
    expect(notifier.state.messages[2].texte, contains('les cinq réponses'));
    expect(notifier.state.messages[3].texte, contains("t'amène le plus"));
  });

  test('plusieurs objectifs cochés : la question les reprend TOUS', () {
    // Le quiz est à choix multiples : n'en redire qu'un, c'est n'avoir
    // écouté qu'à moitié. Avec les mots des cartes, dans l'ordre coché.
    expect(questionIntroDepuisProfil({'goals': 'Mieux dormir|Me reconcentrer'}),
        contains('pour mieux dormir et te reconcentrer'));
    expect(
        questionIntroDepuisProfil({
          'goals': 'Apaiser mon stress|Mieux dormir|Prendre soin de moi',
        }),
        contains('pour apaiser ton stress, mieux dormir '
            'et prendre soin de toi'));
    // Un objectif renommé/inconnu est ignoré, les autres tiennent.
    expect(
        questionIntroDepuisProfil({'goals': 'Objectif disparu|Mieux dormir'}),
        contains('surtout là pour mieux dormir'));
  });

  test('sans réponse d\'onboarding, la question générique reste', () {
    // Vieux compte, onboarding sauté ou objectifs inconnus : le repli est la
    // question ouverte historique, jamais une phrase à côté de la plaque.
    expect(questionIntroDepuisProfil({}), kLouaneIntro.last);
    expect(questionIntroDepuisProfil({'goals': 'Objectif disparu'}),
        kLouaneIntro.last);
    // Profil sans liste mais avec une priorité : elle fait l'affaire.
    expect(questionIntroDepuisProfil({'q1': 'Calmer mon anxiété'}),
        contains('calmer ton anxiété'));
  });

  test('chaque objectif du quiz a ses mots', () {
    // Les intitulés doivent suivre ceux du questionnaire (onboarding_page) :
    // un objectif renommé là-bas sans mise à jour ici retomberait en générique.
    const objectifs = [
      'Apaiser mon stress',
      'Mieux dormir',
      'Calmer mon anxiété',
      'Me reconcentrer',
      'Prendre soin de moi',
    ];
    for (final o in objectifs) {
      expect(questionIntroDepuisProfil({'goals': o}), isNot(kLouaneIntro.last),
          reason: 'pas de reformulation pour : $o');
    }
    // Quatre cochés : on énumère encore (c'est exactement ce qu'elle a pris).
    final quatre = questionIntroDepuisProfil({
      'goals': objectifs.take(4).join('|'),
    });
    expect(quatre,
        contains('apaiser ton stress, mieux dormir, calmer ton anxiété '
            'et te reconcentrer'));
    expect(quatre, contains("c'est bien ça ?"));
    // Les cinq : plus d'inventaire, la variante « tout coché ».
    expect(questionIntroDepuisProfil({'goals': objectifs.join('|')}),
        kQuestionIntroToutCoche);
    expect(bullesDepuisSalutation(kQuestionIntroToutCoche), hasLength(2));
  });

  test('l\'accroche utilise le prénom de l\'onboarding', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefUserFirstName: 'Paul',
    });
    final notifier = await creerNotifier();
    await notifier.jouerIntro();

    expect(notifier.state.messages.first.texte, 'Hey Paul');
  });

  test('sessions suivantes : accroche + phrase adaptée à l\'heure, tapées',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefLouaneIntroVariante: 0,
      AppConstants.prefUserFirstName: 'Paul',
    });
    final notifier = await creerNotifier();

    // Rien n'est seedé : l'accueil se tape en direct à chaque session.
    expect(notifier.state.messages, isEmpty);

    await notifier.jouerIntro();
    final nbBulles = notifier.state.messages.length;
    expect(nbBulles, greaterThanOrEqualTo(2));
    expect(notifier.state.messages.first.texte, 'Hey Paul');
    // La salutation peut être découpée en plusieurs messages (une fin de
    // phrase = un nouveau message) : recollée, elle doit être une variante.
    final suite =
        notifier.state.messages.skip(1).map((m) => m.texte).join(' ');
    expect(salutationsPourHeure(DateTime.now().hour), contains(suite));
    expect(notifier.state.louaneEcrit, isFalse);

    // Et rejouer l'accueil dans la même session ne fait rien.
    await notifier.jouerIntro();
    expect(notifier.state.messages, hasLength(nbBulles));
  });

  test('une salutation se découpe à chaque fin de phrase', () {
    expect(
        bullesDepuisSalutation(
            "Qu'est-ce qui se passe ? Pourquoi t'es toujours debout ?"),
        ["Qu'est-ce qui se passe ?", "Pourquoi t'es toujours debout ?"]);
    expect(bullesDepuisSalutation('Mi-journée :) Tu tiens le rythme ?'),
        ['Mi-journée :)', 'Tu tiens le rythme ?']);
    expect(
        bullesDepuisSalutation('Tôt ce matin... Profite, tout est calme'),
        ['Tôt ce matin...', 'Profite, tout est calme']);
    // Une virgule ne coupe pas : une seule phrase = un seul message.
    expect(
        bullesDepuisSalutation('La journée se lève à peine, prends ton temps'),
        ['La journée se lève à peine, prends ton temps']);
  });

  test('les salutations collent au créneau horaire', () {
    expect(salutationsPourHeure(6).first, contains('Déjà debout'));
    expect(salutationsPourHeure(9).first, contains('démarre'));
    expect(salutationsPourHeure(13).first, contains('midi'));
    expect(salutationsPourHeure(15).first, contains('te voir'));
    expect(salutationsPourHeure(20).first, contains('donné quoi'));
    expect(salutationsPourHeure(23).first, contains('au lit'));
    expect(salutationsPourHeure(0).first, contains('au lit'));
    expect(salutationsPourHeure(3).first, contains('pleine nuit'));
    // Chaque créneau offre plusieurs variantes (anti-répétition).
    for (var h = 0; h < 24; h++) {
      expect(salutationsPourHeure(h).length, greaterThanOrEqualTo(2));
    }
  });

  test('le jour en français est juste (fini le jeudi un vendredi)', () {
    // Ancres connues : le 1ᵉʳ janvier 2024 était un lundi,
    // le 25 décembre 2024 un mercredi.
    expect(jourLocalEnFrancais(DateTime(2024, 1, 1)), 'lundi 1 janvier');
    expect(
        jourLocalEnFrancais(DateTime(2024, 12, 25)), 'mercredi 25 décembre');
  });

  test('les salutations horaires ne redisent jamais bonjour', () {
    // La bulle d'avant dit déjà « Hey prénom » : un deuxième bonjour dans
    // la même volée fait robot (vu en prod : « Hey Paulo » + « Bonsoir toi »).
    const bonjours = ['bonjour', 'bonsoir', 'salut', 'coucou', 'hey', 'hello'];
    for (var h = 0; h < 24; h++) {
      for (final m in salutationsPourHeure(h)) {
        for (final mot in bonjours) {
          expect(m.toLowerCase().contains(mot), isFalse,
              reason: 'deuxième bonjour (« $mot ») dans : $m');
        }
      }
    }
  });

  test('textes d\'accueil : majuscule au début, sans emoji ni tiret long', () {
    const interdits = ['—', '–'];
    final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{FE0F}]',
        unicode: true);
    final textes = [
      ...kLouaneIntro,
      // Les questions d'ouverture composées : chaque objectif seul, un duo,
      // et la totale — les règles de style valent pour toutes.
      for (final o in kObjectifsEnMots.keys)
        questionIntroDepuisProfil({'goals': o}),
      questionIntroDepuisProfil({'goals': 'Apaiser mon stress|Mieux dormir'}),
      questionIntroDepuisProfil({'goals': kObjectifsEnMots.keys.join('|')}),
      for (var h = 0; h < 24; h++) ...salutationsPourHeure(h),
    ];
    for (final m in textes) {
      expect(m[0], m[0].toUpperCase(), reason: 'minuscule au début de : $m');
      for (final tiret in interdits) {
        expect(m.contains(tiret), isFalse,
            reason: 'tiret long/demi dans : $m');
      }
      expect(emoji.hasMatch(m), isFalse, reason: 'emoji dans : $m');
    }
  });
}
