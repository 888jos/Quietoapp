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
    expect(bullesDepuisSalutation('Bien dormi ? Sois honnête :)'),
        ['Bien dormi ?', 'Sois honnête :)']);
    expect(bullesDepuisSalutation('Mi-journée :) Tu tiens le rythme ?'),
        ['Mi-journée :)', 'Tu tiens le rythme ?']);
    expect(
        bullesDepuisSalutation('Tout le monde dort... Nous, on peut parler'),
        ['Tout le monde dort...', 'Nous, on peut parler']);
    // Une virgule ne coupe pas : une seule phrase = un seul message.
    expect(
        bullesDepuisSalutation('La journée se lève à peine, prends ton temps'),
        ['La journée se lève à peine, prends ton temps']);
  });

  test('les salutations collent au créneau horaire', () {
    expect(salutationsPourHeure(6).first, contains('Déjà debout'));
    expect(salutationsPourHeure(9).first, contains('démarre'));
    expect(salutationsPourHeure(13).first, contains('midi'));
    expect(salutationsPourHeure(15).first, contains('après-midi'));
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
