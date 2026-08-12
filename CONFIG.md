# Configuration — Quieto

## Variables à configurer avant le build

### RevenueCat (obligatoire pour la prod) — maj 12/08/2026

Les clés ne sont **plus dans le code** : elles vivent dans `.env.json` (non versionné, à la racine du repo) et sont injectées au build via

```bash
flutter run --dart-define-from-file=.env.json     # idem pour flutter build ipa / appbundle
```

`lib/core/config/revenue_cat_config.dart` les lit avec `String.fromEnvironment('REVENUE_CAT_KEY')` (iOS) et `REVENUE_CAT_KEY_ANDROID`. ⚠️ Sans ce flag, les clés sont vides et les achats ne marchent pas (paywall sans produits).

RevenueCat est initialisé automatiquement dans `main.dart` au démarrage.
Obtenir ou renouveler les clés sur : https://app.revenuecat.com → Project Settings → API Keys

---

## Ajouter des fichiers audio (maj 12/08/2026)

Les séances sont sur **Firebase Storage** (projet `quieto-06`), lues en streaming — plus rien à embarquer dans l'app.

1. Uploader le `.mp3` **à plat** dans le bucket Storage (pas de sous-dossiers) : le lecteur ne garde que le nom de fichier du champ `audioFile` et construit l'URL avec `AppConstants.audioBaseUrl` (voir `audio_handler.dart`). Nom en ASCII pur — voir ADR-024.
2. Déclarer la séance dans `lib/features/explore/data/explore_repository.dart` **et** dans le catalogue backend `quieto-backend/functions/catalogue_seances.json` (« garder synchro avec l'app ») pour que Louane et `genererParcours` la connaissent.

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
- [ ] Build release iOS : `flutter build ipa --dart-define-from-file=.env.json`
- [ ] Build release Android : `flutter build appbundle --dart-define-from-file=.env.json`
- [ ] Mettre à jour `QUIETO.md` + la fiche mémoire fonctionnalités (règle de release)

(Les anciens points « clés placeholders », « audio dans assets/ », « configurer les Bundle ID », « background audio iOS » sont réglés depuis longtemps — voir sections ci-dessus.)
