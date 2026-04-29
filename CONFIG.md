# Configuration — Quieto

## Variables à configurer avant le build

### RevenueCat (obligatoire pour la prod)

La clé API est dans `lib/core/config/revenue_cat_config.dart` :

```dart
const String revenueCatApiKey = 'appl_tQodjeAtfHBnYjPSgcQUGjiRAvi';
```

RevenueCat est initialisé automatiquement dans `main.dart` au démarrage.
Obtenir ou renouveler les clés sur : https://app.revenuecat.com → Project Settings → API Keys

---

## Ajouter des fichiers audio

1. Placer les fichiers `.mp3` dans `assets/audio/`
2. Vérifier que le nom correspond exactement au champ `audioFile` dans `HomeRepository`
3. `flutter pub get` (les assets sont déclarés via `assets/audio/` dans pubspec.yaml)

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
`com.quieto.quieto` — dans `android/app/build.gradle.kts` : `applicationId`. ⚠️ Différent de l'iOS (`com.quietoapp.app`) — à aligner avant la release Android.

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

## Checklist avant release

- [ ] Remplacer les clés RevenueCat placeholders
- [ ] Ajouter les vrais fichiers audio dans `assets/audio/`
- [ ] Configurer Bundle ID iOS et Android
- [ ] Activer la lecture audio en arrière-plan (iOS Info.plist)
- [ ] Tester le flow d'achat en sandbox RevenueCat
- [ ] `flutter analyze` → 0 issue
- [ ] `flutter test` → tous verts
- [ ] Build release iOS : `flutter build ipa`
- [ ] Build release Android : `flutter build appbundle`
