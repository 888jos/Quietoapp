# Quieto

Application de méditation guidée en français (iOS + Android, Flutter) : séances courtes ancrées dans le quotidien + **Louane**, compagnonne IA (chat + programme 7 jours). Version actuelle : **1.0.28+39** (branche `main` ; builds envoyés à App Store Connect et à la Play Console par Paul le 28/09/2026 ; la 1.0.27 est publiée sur l'App Store — maj 28/09/2026).

> Pour comprendre le produit en 5 minutes : lire **`QUIETO.md`**.

> 📁 Depuis le 26/09/2026, l'app est le dossier **`app/`** du dépôt unique `~/Desktop/dev/Quieto` (GitHub privé `Paul-Oll/Quieto`), importée avec son historique. L'ancien dossier `QuietoApp` est une archive : ne plus y travailler.

## Lancer l'app

```bash
flutter run --dart-define-from-file=.env.json
```

⚠️ Le fichier `.env.json` (clés RevenueCat, non versionné) est **obligatoire** — sans lui, `String.fromEnvironment('REVENUE_CAT_KEY')` est vide et les achats ne fonctionnent pas. Pour les builds release, passer par `tool/build-release.sh ipa|appbundle` : même flag, plus `--obfuscate --split-debug-info` (audit sécurité du 02/09/2026).

⚠️ *(maj 28/09/2026)* **`.env.json` n'a pas encore été recopié dans `Quieto/app`.** En attendant, passer le fichier de l'ancien dossier : `--dart-define-from-file=/Users/macbookpaulollivier/Desktop/dev/QuietoApp/.env.json`. `tool/build-release.sh` cherche `.env.json` à la racine de l'app : il ne marche pas tant que le fichier n'y est pas. Autres fichiers non versionnés, déjà recopiés le 28/09 : `lib/firebase_options.dart`, `ios/Runner/GoogleService-Info.plist`, `android/app/google-services.json`, `android/local.properties`.

## Les docs du repo

| Fichier | Rôle |
|---|---|
| `QUIETO.md` | Présentation produit + direction artistique (à jour à chaque release) |
| `ARCHITECTURE.md` | Structure du code, stack, navigation |
| `SPECS.md` | Spécifications produit |
| `CONFIG.md` | Configuration (Firebase, RevenueCat…) |
| `DECISIONS.md` | Décisions techniques datées (append-only) |
| `BUGS_A_CORRIGER.md` | Bugs connus et leur statut |
| `AMELIORATIONS.md` | Backlog produit conversion & rétention (chiffres Vigie) |
| `DIRECTION-ARTISTIQUE.md` | Parti pris visuel (gouache, anti-« look IA ») |
| `PROMPTS-VISUELS.md` | Méthode de génération des images (API Gemini) |
| `AUDIO_SCRIPTS.md` | Scripts des séances audio |
| `CONTRIBUTING.md` | Règles de contribution |
| `../docs/JOURNAL-QUIETO.md` | Journal de bord du projet (source de vérité entre sessions ; dans le dépôt depuis le 26/09/2026) |

Backend (Cloud Functions) : `../backend`. Analytics maison (la Vigie) : `~/Desktop/dev/Quieto IA/analytics` (hors du dépôt). *(maj 28/09/2026)*

*(README réécrit le 12/08/2026 — remplaçait le boilerplate Flutter d'origine.)*
