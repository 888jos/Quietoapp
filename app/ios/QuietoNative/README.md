# QuietoNative

Client iOS natif de Quieto (Swift 5 + SwiftUI, iOS 17 minimum).

## Ouvrir et lancer

1. Installer XcodeGen si nécessaire : `brew install xcodegen`.
2. Dans ce dossier, exécuter `xcodegen generate`.
3. Ouvrir `QuietoNative.xcodeproj` dans Xcode.
4. Choisir la cible **QuietoNative**, puis un simulateur ou l'iPhone connecté.
5. Dans **Signing & Capabilities**, conserver **Automatically manage signing** et sélectionner l'équipe voulue.

Le Team ID local actuellement configuré est `NR772G2FPF`. Le bundle de migration est `com.quietoapp.app.native` afin de ne pas usurper l'identifiant de production pendant cette phase.

## Configuration externe

- Remplacer `REPLACE_WITH_SUPERWALL_PUBLIC_KEY` dans `project.yml` par la clé publique iOS Superwall, puis régénérer le projet. Les placements utilisés sont `home_session_*`, `session_play_*`, `session_download_*`, `louane_session_*` et `manage_subscription`.
- La Cloud Function Louane exige une identité Firebase. Ajouter la configuration Firebase iOS officielle du projet et un adaptateur d'authentification avant de considérer la conversation comme disponible en production. Aucune clé Firebase ou identité de production n'est inventée dans cette cible.
- Les pistes audio restent servies par le bucket Firebase Storage existant. Les téléchargements sont stockés dans Application Support et respectent les placements premium Superwall.
- Remplacer `REPLACE_WITH_SUPABASE_URL` et `REPLACE_WITH_SUPABASE_PUBLISHABLE_KEY` dans `project.yml`, puis régénérer. Seule la clé publishable va dans l’app. L’authentification Supabase fournit le mode anonyme et Sign in with Apple ; la capacité Apple doit aussi être activée sur l’App ID dans le portail Apple.
- Déployer les Edge Functions `account-data` et `louane-proxy` avec `SUPABASE_SECRET_KEY`, `QUIETO_FIREBASE_PROXY_SECRET` et, si nécessaire, `QUIETO_LOUANE_FIREBASE_URL`. Configurer le même `SUPABASE_PROXY_SECRET` dans Firebase Functions. Sans ces secrets, l’app reste utilisable hors ligne mais export, suppression et Louane distante affichent une erreur explicite.
- Le catalogue audio tente d’abord une URL signée du bucket Supabase `session-audio`; pendant la migration, le fallback Firebase Storage reste disponible pour ne pas casser les installations existantes. Un téléchargement n’est déclaré durable qu’après déplacement du fichier dans Application Support.
- Le schéma, le catalogue, le webhook RevenueCat et la procédure de conservation Firebase sont décrits dans `../../../docs/MIGRATION-FIREBASE-SUPABASE.md`.

## Validation locale

```sh
xcodebuild test \
  -project QuietoNative.xcodeproj \
  -scheme QuietoNative \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  CODE_SIGNING_ALLOWED=NO
```
