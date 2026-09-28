# Quieto

Tout le code de Quieto dans un seul dépôt.

| Dossier | Contenu |
|---|---|
| `app/` | L'app Flutter (iOS, Android), historique de `agencymape-coder/Quieto` |
| `backend/` | Firebase : fonctions (Louane, Vigie, Stripe), règles Firestore |
| `sites/entreprise/` | Site Quieto Entreprise (B2B) |
| `sites/cofonde/` | Site cofonde : pages Quieto, CGU, confidentialité |
| `docs/` | Journal de bord, passations, prompt de la voix, audit sécurité |
| `logo/` | Logos Quieto |

## À savoir (maj 28/09/2026)

- **Par où commencer** : `docs/JOURNAL-QUIETO.md` (journal de bord, source de vérité entre les sessions), puis `app/QUIETO.md` (le produit) et `backend/README.md` (le serveur).
- Dépôt créé le 26/09/2026 : `github.com/Paul-Oll/Quieto` (privé), branche `main`. `app/` et `backend/` ont été importés avec leur historique ; les anciens dossiers `QuietoApp` et `quieto-backend` sont des archives.
- **Le push se fait depuis GitHub Desktop** (le git du terminal n'a pas accès au dépôt privé).
- **Hors du dépôt, volontairement** : « Quieto IA » (compta, archives, et la Vigie : `~/Desktop/dev/Quieto IA/analytics`).
- **Fichiers non versionnés, à recopier à la main** : `app/.env.json`, `app/lib/firebase_options.dart`, `app/ios/Runner/GoogleService-Info.plist`, `app/android/app/google-services.json`, `app/android/local.properties`, `backend/functions/.env`, `backend/functions/.secret.local`. Détail et état : `app/CONFIG.md`.
- Version de l'app : **1.0.28+39** (`app/pubspec.yaml`).
