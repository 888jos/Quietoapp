// Le programme de 7 jours créé par Louane (« parcours ») : une séance du
// catalogue par jour + un petit mot d'elle. Généré par la Cloud Function
// `genererParcours`, persisté en local (SharedPreferences), et renvoyé au
// serveur (état résumé) à chaque message pour que Louane suive la
// progression dans la conversation.

/// Un jour du programme. Les infos de séance (titre, durée, premium) sont
/// résolues côté serveur depuis le catalogue et STOCKÉES ici : même si le
/// catalogue de l'app bouge, l'affichage ne casse jamais.
class ParcoursJour {
  final int jour; // 1..7
  final String sessionId;
  final String titreSeance;
  final int dureeMin;
  final bool premium;
  final String motDeLouane;

  const ParcoursJour({
    required this.jour,
    required this.sessionId,
    required this.titreSeance,
    required this.dureeMin,
    required this.premium,
    required this.motDeLouane,
  });

  ParcoursJour copyWith({
    String? sessionId,
    String? titreSeance,
    int? dureeMin,
    bool? premium,
  }) =>
      ParcoursJour(
        jour: jour,
        sessionId: sessionId ?? this.sessionId,
        titreSeance: titreSeance ?? this.titreSeance,
        dureeMin: dureeMin ?? this.dureeMin,
        premium: premium ?? this.premium,
        motDeLouane: motDeLouane,
      );

  Map<String, dynamic> toJson() => {
        'jour': jour,
        'sessionId': sessionId,
        'titreSeance': titreSeance,
        'dureeMin': dureeMin,
        'premium': premium,
        'motDeLouane': motDeLouane,
      };

  factory ParcoursJour.fromJson(Map<String, dynamic> json) => ParcoursJour(
        jour: (json['jour'] as num?)?.toInt() ?? 0,
        sessionId: json['sessionId'] as String? ?? '',
        titreSeance: json['titreSeance'] as String? ?? '',
        dureeMin: (json['dureeMin'] as num?)?.toInt() ?? 0,
        premium: json['premium'] == true,
        motDeLouane: json['motDeLouane'] as String? ?? '',
      );
}

class ParcoursModel {
  final int version;
  final String titre;
  final String sousTitre;
  final List<ParcoursJour> jours;

  /// Date-heure ISO de la création.
  final String creeLe;

  /// Jours terminés : "1" → date-heure ISO de la complétion.
  final Map<String, String> joursTermines;

  /// Date-jour locale ("2026-07-23") de la DERNIÈRE complétion : c'est elle
  /// qui verrouille le rythme (le jour suivant se débloque le lendemain).
  final String? dernierJourTermineLe;

  final bool bilanFait;
  final String? bilanRessenti;

  const ParcoursModel({
    this.version = 1,
    required this.titre,
    required this.sousTitre,
    required this.jours,
    required this.creeLe,
    this.joursTermines = const {},
    this.dernierJourTermineLe,
    this.bilanFait = false,
    this.bilanRessenti,
  });

  /// La date-jour locale au format stocké ("2026-07-23").
  static String cleJourLocal(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Le jour en cours (1..7) : le premier non terminé. Reste à 7 une fois
  /// tout fini (le bilan prend le relais).
  int get jourCourant {
    final n = joursTermines.length + 1;
    return n > 7 ? 7 : n;
  }

  bool get tousJoursTermines => joursTermines.length >= 7;

  /// Terminé = bilan envoyé. La carte accueil disparaît à ce moment-là.
  bool get termine => bilanFait;

  ParcoursJour? jourParNumero(int j) {
    for (final d in jours) {
      if (d.jour == j) return d;
    }
    return null;
  }

  /// La séance du jour en cours (null si programme vide ou incohérent).
  ParcoursJour? get seanceDuJour => jourParNumero(jourCourant);

  bool jourTermine(int j) => joursTermines.containsKey('$j');

  /// La séance du jour a-t-elle été faite AUJOURD'HUI (date-jour locale) ?
  /// Sert au rythme (« à demain ») et au check-in de Louane.
  bool seanceDuJourFaite(String aujourdHui) =>
      dernierJourTermineLe == aujourdHui;

  /// Un jour est jouable si : déjà terminé (réécoute libre), ou jour en cours
  /// ET pas de séance déjà faite aujourd'hui (1 jour par jour, pas de binge).
  bool jourDebloque(int j, String aujourdHui) {
    if (jourTermine(j)) return true;
    if (j != jourCourant || tousJoursTermines) return false;
    return dernierJourTermineLe != aujourdHui;
  }

  ParcoursModel copyWith({
    List<ParcoursJour>? jours,
    Map<String, String>? joursTermines,
    String? dernierJourTermineLe,
    bool? bilanFait,
    String? bilanRessenti,
  }) =>
      ParcoursModel(
        version: version,
        titre: titre,
        sousTitre: sousTitre,
        jours: jours ?? this.jours,
        creeLe: creeLe,
        joursTermines: joursTermines ?? this.joursTermines,
        dernierJourTermineLe: dernierJourTermineLe ?? this.dernierJourTermineLe,
        bilanFait: bilanFait ?? this.bilanFait,
        bilanRessenti: bilanRessenti ?? this.bilanRessenti,
      );

  /// Marque le jour [j] terminé à l'instant [quand].
  ParcoursModel marquerJourTermine(int j, DateTime quand) {
    final maj = Map<String, String>.from(joursTermines);
    maj['$j'] = quand.toIso8601String();
    return copyWith(
      joursTermines: maj,
      dernierJourTermineLe: cleJourLocal(quand),
    );
  }

  ParcoursModel avecBilan(String ressenti) =>
      copyWith(bilanFait: true, bilanRessenti: ressenti);

  /// L'état résumé envoyé au serveur avec chaque message → Louane suit la
  /// progression (check-in) et ne re-propose jamais un programme en cours.
  Map<String, dynamic> pourServeur(String aujourdHui) => {
        'actif': !termine,
        'titre': titre,
        'jour': jourCourant,
        'seanceDuJourFaite':
            tousJoursTermines || seanceDuJourFaite(aujourdHui),
        'termine': termine,
      };

  Map<String, dynamic> toJson() => {
        'version': version,
        'titre': titre,
        'sousTitre': sousTitre,
        'jours': jours.map((j) => j.toJson()).toList(),
        'creeLe': creeLe,
        'joursTermines': joursTermines,
        'dernierJourTermineLe': dernierJourTermineLe,
        'bilanFait': bilanFait,
        'bilanRessenti': bilanRessenti,
      };

  factory ParcoursModel.fromJson(Map<String, dynamic> json) => ParcoursModel(
        version: (json['version'] as num?)?.toInt() ?? 1,
        titre: json['titre'] as String? ?? '',
        sousTitre: json['sousTitre'] as String? ?? '',
        jours: (json['jours'] as List? ?? const [])
            .whereType<Map>()
            .map((j) => ParcoursJour.fromJson(Map<String, dynamic>.from(j)))
            .toList(),
        creeLe: json['creeLe'] as String? ?? '',
        joursTermines:
            Map<String, String>.from(json['joursTermines'] as Map? ?? {}),
        dernierJourTermineLe: json['dernierJourTermineLe'] as String?,
        bilanFait: json['bilanFait'] == true,
        bilanRessenti: json['bilanRessenti'] as String?,
      );
}
