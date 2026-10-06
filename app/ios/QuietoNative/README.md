# QuietoNative

Client iOS natif de Quieto (Swift 5 + SwiftUI, iOS 17 minimum).

## Ouvrir et lancer

1. Installer XcodeGen si nécessaire : `brew install xcodegen`.
2. Dans ce dossier, exécuter `xcodegen generate`.
3. Ouvrir `QuietoNative.xcodeproj` dans Xcode.
4. Choisir la cible **QuietoNative**, puis un simulateur ou l'iPhone connecté.
5. Dans **Signing & Capabilities**, conserver **Automatically manage signing** et sélectionner l'équipe voulue.

Le Team ID local actuellement configuré est `NR772G2FPF`. Le bundle de migration est `com.quietoapp.app.native` afin de ne pas usurper l'identifiant de production pendant cette phase. **Pour la publication, passer à `com.quietoapp.app`** : sinon, les abonnés actuels n'ont pas leur abonnement dans la nouvelle app (voir `docs/MIGRATION-FIREBASE-SUPABASE.md`).

## Onboarding

`Sources/QuietoNative/Onboarding/` contient 40 écrans ; selon les réponses et la configuration, 36 à 40 sont affichés : le 3114, Apple Santé, le compte Apple et la relance du paywall sont conditionnels. Les écrans sont regroupés en sept actes :

1. Accroche.
2. Questionnaire.
3. Filet de sécurité 3114.
4. Première respiration et Louane : ses réponses sont écrites à la main, rien n'est envoyé à l'IA avant l'abonnement.
5. Permissions et engagement.
6. Programme sur 7 jours construit depuis le catalogue (`OnboardingPlanBuilder`).
7. Essai gratuit via le placement Superwall `onboarding_trial`.

Comportements à connaître :
- **Après une fermeture de l'app** : l'onboarding reprend là où la personne s'était arrêtée.
- **Si la personne est déjà abonnée** : elle passe directement dans l'app.
- **Réponse de sécurité** : elle ne quitte jamais l'iPhone.
- **Durée de l'essai** : `OnboardingLinks.trialDays` (7 par défaut) doit correspondre à l'essai configuré dans App Store Connect. L'app planifie le rappel promis 2 jours avant la fin de l'essai.

En debug :
- `QUIETO_FORCE_ONBOARDING=1` relance l'onboarding ;
- `QUIETO_ONBOARDING_STEP=<étape>` ouvre directement une étape, par exemple `plan` ou `paywall`.

## Configuration externe

- **Paywall strict** : sans abonnement actif, `RootView` affiche `HardPaywallView` par-dessus toute l'app. Remplacer `REPLACE_WITH_SUPERWALL_PUBLIC_KEY` dans `project.yml` par la clé publique iOS Superwall, puis régénérer le projet. Le seul placement utilisé est `quieto_hard_paywall`. L'accès est décidé par `QuietoSuperwallService`, qui combine trois sources : le statut Superwall, StoreKit sur l'appareil (fonctionne hors ligne) et la réponse serveur de `subscription-sync` (accès entreprise, anciens abonnements). En debug, `QUIETO_SKIP_PAYWALL=1` dans le schéma ouvre l'app sans abonnement.
- La Cloud Function Louane exige une identité Firebase. Ajouter la configuration Firebase iOS officielle du projet et un adaptateur d'authentification avant de considérer la conversation comme disponible en production. Aucune clé Firebase ou identité de production n'est inventée dans cette cible.
- Les téléchargements passent par une URL signée du bucket privé Supabase `session-audio`, réservé aux abonnés. Ils sont stockés dans Application Support, exclus de la sauvegarde iCloud, et une seule session de téléchargement en arrière-plan est partagée par toute l'app.
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
