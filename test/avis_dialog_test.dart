import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quieto/core/ui/avis_dialog.dart';

/// La carte d'avis en quatre étapes : ce qu'elle rend au ReviewService selon
/// le chemin pris. Les fonds animés (étoiles, avatar) tournent en boucle :
/// on avance le temps à la main, jamais pumpAndSettle.
void main() {
  Future<void> avance(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('« Oui, beaucoup » rend oui, sans retour', (tester) async {
    // Le résultat n'est disponible qu'à la fermeture : on capte par closure.
    AvisResultat? capte;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => capte = await montrerAvisDialog(context),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await avance(tester);
    expect(find.text('Est-ce que Quieto\nte fait du bien ?'), findsOneWidget);
    await tester.tap(find.text('Oui, beaucoup'));
    await avance(tester);
    expect(capte, isNotNull);
    expect(capte!.choix, AvisChoix.oui);
    expect(capte!.aRetour, isFalse);
  });

  testWidgets('« Pas vraiment » puis raisons + mot → retour complet',
      (tester) async {
    AvisResultat? capte;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => capte = await montrerAvisDialog(context),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await avance(tester);
    await tester.tap(find.text('Pas vraiment'));
    await avance(tester);
    expect(find.text("Qu'est-ce qui coince ?"), findsOneWidget);
    await tester.tap(find.text('Le prix'));
    await tester.tap(find.text('Louane'));
    await avance(tester);
    await tester.tap(find.text('Continuer'));
    await avance(tester);
    expect(find.text("Tu m'en dis plus ?"), findsOneWidget);
    await tester.enterText(find.byType(TextField), '  Trop cher pour moi.  ');
    await avance(tester);
    await tester.tap(find.text('Envoyer'));
    await avance(tester);
    expect(find.text("Merci, c'est noté."), findsOneWidget);
    expect(capte, isNull, reason: 'la feuille se referme seule, plus tard');
    await tester.pump(const Duration(seconds: 2));
    await avance(tester);
    expect(capte, isNotNull);
    expect(capte!.choix, AvisChoix.non);
    expect(capte!.raisons, {'prix', 'louane'});
    expect(capte!.texte, 'Trop cher pour moi.');
  });

  testWidgets('la croix garde les raisons validées, pas le brouillon',
      (tester) async {
    AvisResultat? capte;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => capte = await montrerAvisDialog(context),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await avance(tester);
    await tester.tap(find.text('Pas vraiment'));
    await avance(tester);
    await tester.tap(find.text('Ça bugue'));
    await avance(tester);
    await tester.tap(find.text('Continuer'));
    await avance(tester);
    await tester.enterText(find.byType(TextField), 'brouillon jamais envoyé');
    await avance(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await avance(tester);
    // Pas de merci : la feuille se referme tout de suite.
    expect(find.text("Merci, c'est noté."), findsNothing);
    expect(capte, isNotNull);
    expect(capte!.choix, AvisChoix.non);
    expect(capte!.raisons, {'bugs'});
    expect(capte!.texte, isEmpty);
  });

  testWidgets("sans raison cochée, « Continuer » n'avance pas",
      (tester) async {
    AvisResultat? capte;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => capte = await montrerAvisDialog(context),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await avance(tester);
    await tester.tap(find.text('Pas vraiment'));
    await avance(tester);
    expect(find.text('Passer'), findsNothing);
    await tester.tap(find.text('Continuer'));
    await avance(tester);
    expect(find.text("Qu'est-ce qui coince ?"), findsOneWidget);
    expect(find.text("Tu m'en dis plus ?"), findsNothing);
    expect(capte, isNull);
  });

  testWidgets('balayée pendant le merci : la page du dessous reste en place',
      (tester) async {
    // Une page « dessous » poussée par-dessus l'accueil : c'est elle qui
    // ouvre la feuille. Sans le garde-fou, la minuterie du merci dépile
    // cette page (la feuille étant déjà partie) et on retombe sur l'accueil
    // — sur go_router, c'est un écran noir.
    AvisResultat? capte;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Builder(
                    builder: (context) => TextButton(
                      onPressed: () async =>
                          capte = await montrerAvisDialog(context),
                      child: const Text('ouvrir'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('accueil'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('accueil'));
    await avance(tester);
    await tester.tap(find.text('ouvrir'));
    await avance(tester);
    await tester.tap(find.text('Pas vraiment'));
    await avance(tester);
    await tester.tap(find.text('Le prix'));
    await avance(tester);
    await tester.tap(find.text('Continuer'));
    await avance(tester);
    await tester.enterText(find.byType(TextField), 'Trop cher.');
    await avance(tester);
    await tester.tap(find.text('Envoyer'));
    await avance(tester);
    expect(find.text("Merci, c'est noté."), findsOneWidget);
    // Un peu avant la fermeture automatique (1,6 s), la personne touche le
    // voile : la feuille part. La minuterie tombe pendant son animation de
    // sortie, widget encore monté.
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 300));
    await avance(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('ouvrir'), findsOneWidget,
        reason: 'la page du dessous ne doit pas être dépilée');
    expect(find.text('accueil'), findsNothing);
    expect(capte!.raisons, {'prix'});
  });

  testWidgets('feuille balayée à la première question → ignore',
      (tester) async {
    AvisResultat? capte;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => capte = await montrerAvisDialog(context),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await avance(tester);
    // Tap sur le voile, au-dessus de la feuille.
    await tester.tapAt(const Offset(20, 20));
    await avance(tester);
    expect(capte, isNotNull);
    expect(capte!.choix, AvisChoix.ignore);
    expect(capte!.aRetour, isFalse);
  });
}
