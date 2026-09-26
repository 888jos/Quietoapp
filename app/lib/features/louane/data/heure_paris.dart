/// Heure de Paris, calculée depuis l'heure UTC du téléphone — le quota
/// journalier de Louane se réinitialise à minuit HEURE FRANÇAISE, où que
/// soit l'utilisateur. Règles européennes d'heure d'été : UTC+2 du dernier
/// dimanche de mars (01:00 UTC) au dernier dimanche d'octobre (01:00 UTC),
/// UTC+1 le reste de l'année.
library;

DateTime maintenantParis() {
  final utc = DateTime.now().toUtc();
  return utc.add(Duration(hours: _enHeureDEte(utc) ? 2 : 1));
}

/// La date du jour à Paris, ex. "2026-07-05" — sert de clé au compteur.
String cleJourParis() {
  final p = maintenantParis();
  return '${p.year.toString().padLeft(4, '0')}-'
      '${p.month.toString().padLeft(2, '0')}-'
      '${p.day.toString().padLeft(2, '0')}';
}

/// Temps restant avant le prochain minuit à Paris (= retour de Louane).
Duration dureeAvantMinuitParis() {
  final p = maintenantParis();
  final minuit = DateTime.utc(p.year, p.month, p.day).add(const Duration(days: 1));
  return minuit.difference(p);
}

bool _enHeureDEte(DateTime utc) {
  final debut = _dernierDimanche(utc.year, 3).add(const Duration(hours: 1));
  final fin = _dernierDimanche(utc.year, 10).add(const Duration(hours: 1));
  return !utc.isBefore(debut) && utc.isBefore(fin);
}

/// Dernier dimanche du mois, à 00:00 UTC.
DateTime _dernierDimanche(int annee, int mois) {
  final dernierJour = DateTime.utc(annee, mois + 1, 0);
  return dernierJour.subtract(Duration(days: dernierJour.weekday % 7));
}
