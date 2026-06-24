/// Un message dans la conversation avec Louane.
enum AuteurMessage { user, louane }

class LouaneMessage {
  final AuteurMessage auteur;
  final String texte;

  const LouaneMessage({required this.auteur, required this.texte});

  bool get estLouane => auteur == AuteurMessage.louane;
}
