# Configuration — Quieto

## Variables à configurer avant le build

### RevenueCat (obligatoire pour la prod) — maj 12/08/2026

Les clés ne sont **plus dans le code** : elles vivent dans `.env.json` (non versionné, à la racine du repo) et sont injectées au build via

```bash
flutter run --dart-define-from-file=.env.json     # idem pour flutter build ipa / appbundle
```

`lib/core/config/revenue_cat_config.dart` les lit avec `String.fromEnvironment('REVENUE_CAT_KEY')` (iOS) et `REVENUE_CAT_KEY_ANDROID`. ⚠️ Sans ce flag, les clés sont vides et les achats ne marchent pas (paywall sans produits).

⚠️ **Dépôt unique (maj 28/09/2026).** Depuis le 26/09/2026 l'app est le dossier `app/` du dépôt `~/Desktop/dev/Quieto` : « la racine du repo » ci-dessus se lit **`Quieto/app/`**. **`.env.json` n'y a pas encore été recopié** : en attendant, les builds passent `--dart-define-from-file=/Users/macbookpaulollivier/Desktop/dev/QuietoApp/.env.json` (ancien dossier, archive). `tool/build-release.sh` cherche `.env.json` dans `app/` et ne marche pas sans lui.

### Fichiers non versionnés à recopier après un clone (maj 28/09/2026)

| Fichier | État dans `Quieto/app` au 28/09 |
|---|---|
| `.env.json` | **absent** — à recopier par Paul |
| `lib/firebase_options.dart` | recopié le 28/09 |
| `ios/Runner/GoogleService-Info.plist` | recopié le 28/09 |
| `android/app/google-services.json` | recopié le 28/09 |
| `android/local.properties` | recopié le 28/09 |

Côté backend : `backend/functions/.env` et `backend/functions/.secret.local` (recopiés le 26/09). Tous sont ignorés par git (`app/.gitignore`, `backend/.gitignore`, `backend/functions/.gitignore`).

RevenueCat est initialisé automatiquement dans `main.dart` au démarrage.
Obtenir ou renouveler les clés sur : https://app.revenuecat.com → Project Settings → API Keys

---

## Ajouter des fichiers audio (maj 12/08/2026)

Les séances sont sur **Firebase Storage** (projet `quieto-06`), lues en streaming — plus rien à embarquer dans l'app.

1. Uploader le `.mp3` **à plat** dans le bucket Storage (pas de sous-dossiers) : le lecteur ne garde que le nom de fichier du champ `audioFile` et construit l'URL avec `AppConstants.audioBaseUrl` (voir `audio_handler.dart`). Nom en ASCII pur — voir ADR-024.
2. Déclarer la séance dans `lib/features/explore/data/explore_repository.dart` **et** dans le catalogue backend `../backend/functions/catalogue_seances.json` (avant le 26/09/2026 : `quieto-backend/…`) (« garder synchro avec l'app ») pour que Louane et `genererParcours` la connaissent.

Format recommandé : MP3 128kbps, mono, normalisé à -16 LUFS.

---

## iOS — Configuration Xcode

### Permissions audio (déjà non requises pour `just_audio` en lecture)

Pour la lecture en arrière-plan, ajouter dans `ios/Runner/Info.plist` :

```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
```

### Bundle ID
`com.quietoapp.app` — modifier dans Xcode → Runner → Signing & Capabilities.

---

## Android — Configuration

### Bundle ID
`com.quieto.quieto` — dans `android/app/build.gradle.kts` : `applicationId`. ⚠️ Différent de l'iOS (`com.quietoapp.app`) — c'est resté ainsi en prod (l'app est sortie sur les deux stores avec ces IDs), ne plus chercher à les aligner. (maj 12/08/2026)

### Permissions (AndroidManifest.xml)
`just_audio` ne nécessite pas de permissions supplémentaires pour les assets locaux.

---

## Tests sur iPhone physique — repartir « nouvel utilisateur » (maj 22/09/2026)

Sur un vrai iPhone, le trousseau survit à la désinstallation : le compte anonyme Firebase et le coffre chiffré (prénom, mémoire Louane, profil d'onboarding) reviennent à la réinstallation. Pour tester comme une personne qui découvre l'app, builder en debug avec :

```bash
flutter build ios --debug --dart-define-from-file=.env.json --dart-define=NOUVEL_UTILISATEUR=true
flutter run -d <udid> --use-application-binary=build/ios/iphoneos/Runner.app
```

`main.dart` efface alors trousseau + préférences **une seule fois par installation** (marqueur `nouvel_utilisateur_fait`), avant la connexion anonyme. Sans effet hors debug ou sans le define. Sur simulateur, inutile : un simulateur neuf est vierge.

---

## Tests sur iPhone physique — jeton App Check debug (maj 28/08/2026)

En debug, App Check utilise le **provider de débogage** (`main.dart` : `AppleDebugProvider` / `AndroidDebugProvider` sous `kDebugMode`). Le jeton de débogage est propre à chaque installation : **réinstaller un build debug en génère un nouveau**, à enregistrer dans la console Firebase (projet `quieto-06` → App Check → Apps → gérer les jetons de débogage) — sinon **tous les appels aux Cloud Functions échouent depuis ce build** (Louane, `trace`/Vigie : erreurs `HttpsCallable` dans les logs). Le jeton s'affiche dans la console Xcode au premier lancement. Le jeton courant du build de test de Paul est noté dans `~/dev/JOURNAL-QUIETO.md` (pas ici : ce repo est poussé). ⚠️ *(maj 28/09/2026)* Le journal est maintenant `../docs/JOURNAL-QUIETO.md`, **dans le même dépôt**, poussé sur GitHub (privé) : la précaution « pas ici » ne tient plus, le jeton du 28/08 est dans un fichier versionné.

---

## Environnements

| Variable | Dev | Prod |
|---|---|---|
| RevenueCat debug | `Purchases.setLogLevel(LogLevel.debug)` | Désactiver |
| GoRouter logs | `debugLogDiagnostics: true` | `false` |
| Flutter debugBanner | automatique | automatique |

---

## Checklist avant release (maj 12/08/2026)

- [ ] Tester le flow d'achat en sandbox RevenueCat
- [ ] `flutter analyze` → 0 issue
- [ ] `flutter test` → tous verts
- [ ] Build release iOS : `tool/build-release.sh ipa` (= `flutter build ipa --dart-define-from-file=.env.json --obfuscate --split-debug-info=symbols/<version>`)
- [ ] Build release Android : `tool/build-release.sh appbundle`
- [ ] Archiver le dossier `symbols/<version>/` avec la release (lecture des crashs ; jamais dans git)
- [ ] Mettre à jour `QUIETO.md` + la fiche mémoire fonctionnalités (règle de release)
- [ ] *(ajout 28/09/2026)* Bumper **`AppConstants.appVersion`** (`lib/core/config/app_constants.dart`) en même temps que `pubspec.yaml` : c'est lui qu'envoie la Vigie. Au 28/09 il est resté à `1.0.25` alors que `pubspec.yaml` est à `1.0.28+39`.
- [ ] *(ajout 28/09/2026)* **Fermer Xcode** avant `tool/build-release.sh ipa`, et ne jamais re-archiver depuis Xcode (l'archive perd les `--dart-define`, donc la clé RevenueCat — c'est ce qui a cassé le paywall de la 1.0.22, sortie le 01/09/2026) ; vérifier la version, le numéro de build et la présence de la clé dans l'archive avant l'envoi.

(Les anciens points « clés placeholders », « audio dans assets/ », « configurer les Bundle ID », « background audio iOS » sont réglés depuis longtemps — voir sections ci-dessus.)
