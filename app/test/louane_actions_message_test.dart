import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quieto/core/services/storage_service.dart';
import 'package:quieto/core/services/vigie_service.dart';
import 'package:quieto/features/louane/data/louane_message.dart';
import 'package:quieto/features/louane/data/louane_repository.dart';
import 'package:quieto/features/louane/louane_providers.dart';
import 'package:quieto/features/louane/presentation/widgets/menu_bulle.dart';

/// Actions sur un message envoyé (22/09/2026) : renvoyer (tel quel ou
/// modifié) ramène le fil juste avant lui ; supprimer retire le message et
/// la réponse de Louane qui le suit ; restaurer annule la suppression.
void main() {
  const fil = [
    LouaneMessage(auteur: AuteurMessage.louane, texte: 'Hey'),
    LouaneMessage(auteur: AuteurMessage.user, texte: 'Je dors mal'),
    LouaneMessage(auteur: AuteurMessage.louane, texte: "D'accord"),
    LouaneMessage(auteur: AuteurMessage.louane, texte: 'Depuis quand ?'),
    LouaneMessage(auteur: AuteurMessage.user, texte: 'Une semaine'),
    LouaneMessage(auteur: AuteurMessage.louane, texte: 'Je vois'),
  ];

  Future<LouaneChatNotifier> creerNotifier() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final vigie = VigieService(prefs);
    final repo = LouaneRepository(storage, vigie, () => false);
    final n = LouaneChatNotifier(repo, vigie, () => false, storage);
    n.state = n.state.copyWith(messages: fil);
    return n;
  }

  test('renvoyer modifié : la suite disparaît, le nouveau texte repart',
      () async {
    final n = await creerNotifier();
    await n.renvoyer(1, 'Je dors très mal');
    final m = n.state.messages;
    // Sans serveur dans les tests, l'envoi échoue et Louane s'excuse : ce
    // qui compte, c'est le fil juste avant : Hey, puis le message modifié.
    expect(m[0].texte, 'Hey');
    expect(m[1].texte, 'Je dors très mal');
    expect(m[1].auteur, AuteurMessage.user);
    expect(m.any((x) => x.texte == 'Une semaine'), isFalse);
    expect(m.any((x) => x.texte == 'Depuis quand ?'), isFalse);
  });

  test('renvoyer refuse une bulle de Louane et un index hors fil', () async {
    final n = await creerNotifier();
    await n.renvoyer(0, 'x');
    await n.renvoyer(42, 'x');
    expect(n.state.messages.length, fil.length);
  });

  test('supprimer retire le message et la réponse qui le suit, restaurer annule',
      () async {
    final n = await creerNotifier();
    final retires = n.supprimer(1);
    expect(retires.map((x) => x.texte), ['Je dors mal', "D'accord", 'Depuis quand ?']);
    expect(n.state.messages.map((x) => x.texte), ['Hey', 'Une semaine', 'Je vois']);
    n.restaurer(1, retires);
    expect(n.state.messages.map((x) => x.texte), fil.map((x) => x.texte));
  });

  test('supprimer le dernier échange', () async {
    final n = await creerNotifier();
    final retires = n.supprimer(4);
    expect(retires.length, 2);
    expect(n.state.messages.length, 4);
    expect(n.supprimer(0), isEmpty); // bulle de Louane : rien
  });

  test('chaque message reçoit sa date en entrant dans le fil', () async {
    final n = await creerNotifier();
    expect(n.state.messages.every((m) => m.date != null), isTrue);
    final d = n.state.messages.first.date!;
    n.state = n.state.copyWith(messages: [
      ...n.state.messages,
      const LouaneMessage(auteur: AuteurMessage.user, texte: 'Encore'),
    ]);
    expect(n.state.messages.first.date, d); // les anciennes ne bougent pas
    expect(n.state.messages.last.date, isNotNull);
  });

  test('en-tête du menu : « 15 sept. 2026 à 16:50 »', () {
    expect(formaterDateMessage(DateTime(2026, 9, 15, 16, 50)), '15 sept. 2026 à 16:50');
    expect(formaterDateMessage(DateTime(2026, 1, 3, 9, 5)), '3 janv. 2026 à 09:05');
  });
}
