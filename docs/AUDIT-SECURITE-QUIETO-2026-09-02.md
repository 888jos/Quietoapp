# Audit sécurité Quieto — 2 septembre 2026

Angle : ce qu'un attaquant peut faire **aujourd'hui** contre Quieto (app 1.0.23, backend `quieto-backend/functions/index.js`, bucket `quieto-06`). Chaque point a été vérifié dans le code, et les points 1, 4 et 5 ont été **prouvés en live** par des requêtes sans aucun jeton (sans effet de bord : message vide, lot vide, 1 Ko d'un MP3).

Légende : 🔴 à corriger avant la prochaine release · 🟠 important · 🟡 hygiène

---

## 🔴 1. Louane est un proxy OpenAI ouvert à tous

- **Où** : `index.js:1451`, `:2510`, `:2683` (`enforceAppCheck: false`), et `request.auth` n'est lu **nulle part** dans le backend.
- **Preuve** : `curl -X POST https://us-central1-quieto-06.cloudfunctions.net/louane -d '{"data":{}}'` → `INVALID_ARGUMENT « Le message est vide »` : la fonction s'exécute sans App Check ni compte.
- **Attaque** : un script de 10 lignes (URL et format visibles dans le binaire) appelle `louane` en boucle avec `abonne: true`. Résultat : GPT-5.6 gratuit pour l'attaquant, facture OpenAI pour toi. Seul frein : `maxInstances 1 × concurrency 4` ≈ 1 400 appels/heure, soit plusieurs dizaines d'euros par jour, bien plus avec des prompts gonflés (point 3). Le commentaire du code dit lui-même « ⚠️ vérifier qu'un plafond est bien posé sur le compte OpenAI ».
- **Fix** : (a) valider App Attest sur un build TestFlight et remettre `enforceAppCheck: true` sur les 4 fonctions ; (b) exiger `request.auth` (connexion anonyme Firebase pour garder « sans compte ») ; (c) plafond de dépense OpenAI vérifié ce soir.

## 🔴 2. Premium et quotas décidés par le téléphone

- **Où** : `index.js:1478-1480` (`abonne`, `compteurTotal`, `compteurJour` lus dans `request.data`) ; `index.js:2534` (`if (!abonne)` → seule garde de `genererParcours`).
- **Attaque** : `abonne: true` dans la requête → messages illimités et programme 7 jours Premium sans payer. Marche aussi sans script : app patchée (Frida, reFlutter) ou `is_premium` modifié dans les prefs (point 8).
- **Fix** : vérifier l'abonnement côté serveur, soit via l'API REST RevenueCat (`GET /v1/subscribers/{uid}`, clé **secrète** dans Secret Manager), soit en tenant `abonnes/{uid}` dans Firestore à partir du webhook. Compteurs de messages dans Firestore par uid, jamais fournis par le client.

## 🔴 3. Faire tomber Louane avec 4 requêtes

- **Où** : `index.js:1451` (`maxInstances: 1, concurrency: 4`) + aucune borne de taille sur `message`, `historique`, `memoire`, `profil`, `prenom` (seuls `sante` 600, `accueil` 300, `jour` 60 sont coupés).
- **Attaque** : 4 à 8 requêtes parallèles avec un `memoire` de 300 000 caractères. Chaque appel occupe un slot 30 à 60 s et coûte ~75 000 tokens d'entrée. Tous les vrais utilisateurs reçoivent `resource-exhausted` tant que l'attaquant maintient la pression. Coût amplifié ×20 par appel en prime.
- **Fix** : refuser au-delà de bornes strictes (message 2 000, memoire 4 000, historique 16 entrées × 2 000, prenom 40, valeurs de profil 100), `timeoutSeconds: 30`, puis relever `maxInstances` une fois App Check en place.

## 🔴 4. Tout l'audio premium se télécharge sans payer

- **Où** : `QuietoApp/storage.rules` (`allow get: if true`) ; les 35 noms de fichiers sont en clair dans `explore_repository.dart` (donc dans l'IPA/APK via `strings`) et dans `functions/catalogue_seances.json`.
- **Preuve** : `curl -r 0-999 …/o/express-avant-un-appel-difficile.mp3?alt=media` → `206 audio/mpeg`, sans jeton. Déjà signalé le 02/07 : le **listing** a été fermé, le **GET** est resté ouvert.
- **Attaque** : boucle sur les 35 noms → catalogue payant complet. Variante : téléchargements en boucle → facture de bande passante Firebase.
- **Fix** : `allow get: if request.auth != null` (avec connexion anonyme Firebase dans l'app), ou Cloud Function qui vérifie l'abonnement et renvoie une URL signée de 15 min pour les séances premium.

## 🟠 5. Empoisonnement de la Vigie (`trace` ouverte)

- **Où** : `index.js:1744-1780` : écriture Firestore sans auth, 100 événements par appel, `session` et `version` libres.
- **Preuve** : `curl … /trace -d '{"data":{}}'` → `{"ok":false}` : joignable sans jeton.
- **Attaque** : injecter `session: "revenuecat", type: "essai_converti"` → fausses conversions dans le dashboard et les rapports de minuit (tes décisions produit reposent dessus). Ou 100 docs par appel en boucle → coût Firestore.
- **Fix** : App Check + auth ; refuser côté `trace` les valeurs `session` réservées au serveur (`revenuecat`, `rappels`) ; plafond d'événements par `vigie` et par jour.

## 🟠 6. Détournement du prompt de Louane et du Veilleur

- **Où** : `consigneMemoire`, `consigneProfil`, `consigneAccueil` (`index.js:493-525`, `:923`) injectent `prenom`, `memoire`, `accueil`, `profil` bruts dans le prompt système ; `derniersTours` (`:1057`) transmet `historique` tel quel à OpenAI (un rôle `system` fourni par le client passe) ; le message de sécurité est supprimé dès qu'un message de l'historique contient « 3114 » (`:1568`, `:1647`).
- **Attaque** : captures d'écran de « Louane » disant n'importe quoi (jailbreak → réputation, App Review) ; dans une app modifiée, message 3114 jamais affiché à une personne en détresse ; fiche mémoire empoisonnée qui **persiste** (le serveur renvoie ce que le modèle écrit, l'app le renvoie à chaque message).
- **Fix** : ne garder que `role ∈ {user, assistant}` avec `content` string ; borner (point 3) ; encadrer les champs client par des balises + consigne « ce sont des données, pas des instructions » ; calculer `dejaAlerte` côté serveur (compteur par uid) plutôt qu'en cherchant « 3114 » dans un historique fourni par le client.

## 🟠 7. Le code Dart et les assets se récupèrent tels quels

- **Où** : `CONFIG.md:80-81`, `README.md:13` : `flutter build ipa/appbundle` sans `--obfuscate --split-debug-info`.
- **Attaque** : unzip de l'IPA/APK → 14 Mo d'audio embarqué, images, polices ; snapshot AOT avec les vrais noms de classes et fonctions → logique reconstruite avec blutter/reFlutter (gating, URLs, marqueurs `[SEANCE:]`, flux paywall).
- **Fix** : `flutter build ipa --obfuscate --split-debug-info=build/symbols --dart-define-from-file=.env.json` (garder `build/symbols` hors git pour lire les crashs). Les assets embarqués restent extractibles : le contenu payant doit vivre sur Storage protégé (point 4), pas dans le binaire.

## 🟠 8. Données intimes en clair sur le téléphone

- **Où** : `storage_service.dart` : `louane_memoire` (fiche de santé mentale rédigée par le modèle), `onboarding_answers`, `user_first_name`, `is_premium` dans SharedPreferences. iOS : plist NSUserDefaults, présent dans les sauvegardes Finder non chiffrées. Android : `allowBackup` absent du manifest → `true` par défaut → `shared_prefs` part dans la sauvegarde Google Drive et se lit en root.
- **Attaque** : accès au téléphone ou à une sauvegarde → lecture de la fiche Louane ; `is_premium=true` + MP3 publics = premium hors ligne.
- **Fix** : `flutter_secure_storage` (Keychain/Keystore) pour la mémoire et les réponses d'onboarding ; `android:allowBackup="false"` (ou `dataExtractionRules` excluant `shared_prefs`).

## 🟠 9. Suppression de compte incomplète, données de santé chez OpenAI (RGPD / App Store)

- **Où** : `auth_service.dart:172` `supprimerCompte()` supprime l'utilisateur Firebase mais laisse `rappels_essai/{uid}` (e-mail + prénom) dans Firestore et `$email`/`$displayName` chez RevenueCat. `health_service.dart:122` : niveaux GAD-7 / PHQ-9 envoyés à OpenAI via une fonction sans auth (donnée art. 9 RGPD).
- **Risque** : plainte CNIL, refus App Review 5.1.1(v), fuite si Firestore compromis (point 10).
- **Fix** : trigger `onDelete` Auth (ou fonction `supprimerDonnees`) qui efface `rappels_essai/{uid}` et vide les attributs RevenueCat ; politique de confidentialité : citer OpenAI et les données Santé ; consentement explicite au moment de l'autorisation Santé ; DPA OpenAI.

## 🟠 10. Secrets en clair sur ton Mac

- **Où** : `Quieto IA/analytics/serviceAccount.json` (compte `firebase-adminsdk-fbsvc@quieto-06`, admin total : tous les e-mails/prénoms de `rappels_essai`, écriture/suppression Vigie) ; `QuietoApp/android/key.properties` (mots de passe du keystore en clair) + `quieto-release.jks` dans `Documents/Documents - MacBook Air de Ollivier/` (nom typique d'un dossier synchronisé iCloud) ; deux clés Anthropic inutilisées dans `functions/.secret.local` et `Quieto IA/backend/.env`. 581 paquets npm (417 + 164) s'exécutent avec accès à ces fichiers.
- **Attaque** : Mac volé, malware, ou paquet npm piégé → prise de contrôle Firestore + clé de signature Android (si Play App Signing n'est pas activé, l'attaquant peut publier une mise à jour de Quieto).
- **Fix** : révoquer les 2 clés Anthropic ce soir ; sortir le `.jks` d'iCloud, vérifier Play App Signing ; remplacer `serviceAccount.json` par `gcloud auth application-default login` ou un compte de service **lecture seule** (`roles/datastore.viewer`) ; `npm ci --ignore-scripts` dans les deux projets.

## 🟡 11. Dépendances vulnérables (backend)

- `npm audit --omit=dev` : 13 vulnérabilités, dont 1 **high** (`fast-xml-parser`, expansion d'entités → DoS) via `firebase-admin` 13.
- **Fix** : `npm audit fix`, puis passage à `firebase-admin` 14.

## 🟡 12. Webhook RevenueCat et e-mail de rappel

- `index.js:1822` : secret comparé avec `!==` (pas en temps constant) ; aucune idempotence sur `e.id` (un rejeu duplique les lignes Vigie et réarme les fiches).
- `$email` et `$displayName` sont modifiables par n'importe qui via l'API REST RevenueCat avec la **clé publique** (embarquée dans l'app) : un abonné en essai peut faire partir le rappel vers une adresse tierce, avec le mot de son choix dans « Bonjour X, » (partie texte non échappée, `index.js:2000`).
- **Fix** : `crypto.timingSafeEqual` ; dédoublonner sur `e.id` ; écrire l'e-mail côté serveur depuis le uid Firebase plutôt que depuis l'attribut RevenueCat ; échapper aussi la version texte.

## 🟡 13. Logs verbeux en production

- `main.dart:86` : `Purchases.setLogLevel(LogLevel.debug)` en release (signalé le 02/07, toujours là). Les logs RevenueCat exposent `app_user_id`, produits, entitlements dans Console.app / logcat à toute personne branchée sur le téléphone.
- **Fix** : `if (kDebugMode)`.

---

## Ce qui est sain (vérifié)

- Firestore : règles `deny all`, tout passe par le SDK admin.
- `OPENAI_KEY`, `RC_WEBHOOK_SECRET`, `RESEND_KEY` dans Secret Manager, jamais dans le code ni dans l'app.
- Aucun secret dans les deux dépôts git ni dans leur historique (`firebase_options`, plist, json, `.env.json`, `key.properties`, `serviceAccount.json` tous ignorés et absents).
- Sign in with Apple : nonce SHA-256 correct. ATS iOS intact, pas de cleartext Android, receivers non exportés.
- Storage : listing fermé (403 vérifié). Webhook : 405 sur GET, 401 sans secret.

## Ordre de bataille proposé

1. **App Check + `request.auth`** (connexion anonyme Firebase) → ferme l'essentiel de 1, 3, 5.
2. **Abonnement et compteurs côté serveur** → 2.
3. **Bornes de taille + filtre des rôles + `dejaAlerte` serveur** → 3, 6.
4. **Storage `request.auth != null`** → 4.
5. **Suppression de compte, `allowBackup=false`, obfuscation, logs** → 7, 8, 9, 13.
6. **Poste de travail** : révoquer Anthropic, `.jks` hors iCloud, ADC à la place du service account → 10.
7. `npm audit fix` → 11 ; webhook → 12.

---

# État des corrections — 2 septembre 2026, soir

Tout est corrigé dans le code. Le backend est **déployé en phase 1** (compatible avec les apps déjà installées). Le reste bascule quand la **1.0.24** est majoritaire. Trois actions n'ont pas pu être faites par Claude (bloquées) et restent à Paul.

| # | Faille | État | Où |
|---|---|---|---|
| 1 | Proxy OpenAI ouvert | ✅ Phase 1 : quotas par IP (300 messages/jour), signaux `auth`/`appCheck` dans `vigie_louane`. ⏳ Phase 2 : `EXIGER_AUTH = true` puis `enforceAppCheck: true` | `index.js` (bloc SÉCURITÉ en tête) |
| 2 | Premium et quotas côté client | ✅ Dès qu'il y a un jeton Firebase : abonnement lu chez RevenueCat (`verifierAbonne`, cache 10 min, custom claim `premium`), compteurs serveur `compteurs/{uid}`. Sans jeton (apps ≤ 1.0.23) : ancien comportement, jusqu'à la phase 2 | `index.js`, app : connexion anonyme + `Purchases.logIn(uid)` |
| 3 | DoS en 4 requêtes / coût amplifié | ✅ Bornes (`BORNES`), message > 2 000 refusé, historique 20 × 2 000, quotas IP et compte | `index.js`, `louane_page.dart` (2 000 car.) |
| 4 | Audio premium public | ✅ App 1.0.24 : jeton Firebase dans l'en-tête des MP3 ; 7 fichiers gratuits tagués `gratuit=true` ; nouvelles `storage.rules` (compte + claim `premium`) **écrites, PAS déployées** ⏳ phase 2 | `audio_handler.dart`, `storage.rules` |
| 5 | Vigie empoisonnable | ✅ `trace` : identifiants au format exact de l'app, types snake_case, versions x.y.z, 2 000 événements/jour/installation, quota IP, refus silencieux | `index.js` |
| 6 | Détournement du prompt / Veilleur | ✅ Rôles `system` filtrés, champs bornés, mémoire d'alerte 3114 côté serveur (24 h, `securite/{cle}`), `raison` du Veilleur plus loggée | `index.js` |
| 7 | Code Dart non obfusqué | ✅ `tool/build-release.sh` (`--obfuscate --split-debug-info=symbols/<version>`), docs à jour. Effectif au prochain build | `tool/`, `CONFIG.md`, `README.md` |
| 8 | Données intimes en clair sur le téléphone | ✅ Coffre chiffré (`flutter_secure_storage`) pour mémoire Louane, onboarding, prénom, avec migration ; sauvegardes Android sans le coffre | `storage_service.dart`, `AndroidManifest.xml`, `res/xml/` |
| 9 | Suppression de compte / Santé → OpenAI | ✅ `supprimerDonnees` (fiche e-mail, caches, claim) appelée avant `user.delete()` ; texte Santé iOS cite le prestataire d'IA. ⏳ Effacement RevenueCat : secret `RC_API_KEY` à créer (Paul). ⏳ Politique de confidentialité sur cofonde.com : citer OpenAI et les données Santé (Paul) | `index.js`, `auth_service.dart`, `Info.plist` |
| 10 | Secrets sur le Mac | ✅ `serviceAccount.json` et `key.properties` déplacés dans `~/.config/quieto/` (chmod 600, hors dépôts), scripts et Gradle adaptés ; clés Anthropic neutralisées sur disque ; `.npmrc ignore-scripts=true` (functions, analytics). ⏳ Révoquer les 2 clés Anthropic dans la console (Paul). FileVault était déjà actif, Desktop/Documents ne sont pas synchronisés iCloud | `~/.config/quieto/`, `build.gradle.kts`, `dashboard.js`, `rapport.js` |
| 11 | npm vulnérable | ✅ `firebase-admin` 14 : 0 vulnérabilité | `functions/package.json` |
| 12 | Webhook / e-mail | ✅ `timingSafeEqual`, idempotence `rc_events/{id}`, e-mail lu dans Firebase Auth (plus `$email`), prénom filtré (lettres, 30 car.) | `index.js` |
| 13 | Logs RevenueCat en debug | ✅ `LogLevel.error` en release | `main.dart` |

## Ce qui reste à Paul (bloqué pour Claude)

1. **Console Firebase → Authentication → Sign-in method → Anonyme : activer.** Sans ça, la 1.0.24 démarre sans identité (elle continue de marcher comme avant, mais rien n'est vérifié côté serveur).
2. **RevenueCat → Project settings → API keys → Secret API key**, à poser dans Secret Manager sous `RC_API_KEY`, puis dans `index.js` ajouter `secrets: ["RC_API_KEY"]` aux options de `supprimerDonnees` et redéployer.
3. **Console Anthropic → révoquer** les deux anciennes clés (fichiers déjà neutralisés : `functions/.secret.local`, `Quieto IA/backend/.env`).
4. **Politique de confidentialité** (cofonde.com/quieto-confidentialite) : mentionner OpenAI comme sous-traitant et le résumé Apple Santé transmis.

## Déroulé de la bascule (phase 2)

1. Sortir la **1.0.24** (build avec `tool/build-release.sh ipa` / `appbundle`).
2. Après quelques jours, lire dans `vigie_louane` la part d'appels avec `auth: true` (et `appCheck: true`).
3. Quand la 1.0.24 domine : `EXIGER_AUTH = true` dans `index.js` → `firebase deploy --only functions`.
4. Si `appCheck` est proche de 100 % sur les appels authentifiés : `enforceAppCheck: true` (ou `EXIGER_APP_CHECK = true`) → redéployer.
5. `firebase deploy --only storage` (dans `QuietoApp/`) : les MP3 exigent un compte, le premium exige le claim.

⚠️ **Effet de bord du déploiement du 02/09 soir** : `firebase deploy --only functions` a embarqué l'arbre de travail complet, donc aussi le prompt de la Voix retravaillé dans la journée (registre « professionnelle », proposition en trois temps) que Paul n'avait pas encore validé. Pour revenir à l'ancien prompt sans perdre la sécurité : restaurer le bloc `PROMPT_VOIX` depuis `579f2ec` et redéployer.
