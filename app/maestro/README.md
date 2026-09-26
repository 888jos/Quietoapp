# Parcours de test Maestro — Quieto

Flows utilisés par l'agent **quieto-testeur** pour piloter l'app sur simulateur comme un humain.

- Prérequis (à exporter avant chaque commande) :
  `export JAVA_HOME=/opt/homebrew/opt/openjdk@17 && export PATH="$JAVA_HOME/bin:$HOME/.maestro/bin:$PATH"`
- Lancer un flow : `maestro test maestro/<flow>.yaml`
- Voir ce qu'il y a à l'écran : `maestro hierarchy`
- L'app doit déjà être installée sur le simulateur (`flutter run -d <UUID> --dart-define-from-file=.env.json`).

Convention : numéroter les flows dans l'ordre du parcours utilisateur
(`01_lancement`, `02_onglets`, `03_seance`, …).
L'agent les enrichit au fil de ses sessions de test.

Règles (détail dans `.claude/agents/quieto-testeur.md`, modèle : `02_onglets.yaml`) :
- `stopApp: false` partout sauf `01_lancement` (sinon la session `flutter run` meurt) ;
- un tap d'échauffement après `launchApp` (le premier tap peut être avalé) ;
- un assert après chaque navigation, jamais de capture aveugle ;
- les `takeScreenshot` atterrissent dans `~/.maestro/tests/<horodatage>/…`, pas dans le projet.
