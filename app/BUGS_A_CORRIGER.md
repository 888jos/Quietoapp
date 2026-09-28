# 🐛 Bugs à corriger — Quieto

> Backlog des bugs trouvés par l'équipe d'agents de nuit (24/06/2026) et **vérifiés**.
> Rapport complet : `../Quieto IA/rapports-nuit/rapport-nuit-1.md`.
> ⚠️ **Aucun n'est urgent** — rien de cassé en production. À traiter quand tu veux.
> 🔎 **Point de contrôle du 12/08/2026** : chaque bug re-vérifié dans le code. Bugs 1 à 7 : **toujours ouverts** (nuances notées en italique dans les fiches). Bug 8 : **résolu**.
> 🔎 **Point de contrôle du 26/08/2026** (préparation 1.0.20) : bugs 1 à 7 re-vérifiés dans le code — **tous toujours ouverts, état strictement identique au 12/08** (artwork à chemin fixe et écriture non protégée ; retour du lecteur en `go('/category/…')` hors `viaLancement` ; splash à 5 500 ms ; `lastPositions` jamais branché ; `saveProgress` loggé mais avalé). Le grand ménage du 26/08 (`9e82c22`) portait sur les outils de dev, pas sur ces fiches.
> 🔎 **Point de contrôle du 28/08/2026** : rien de changé sur les fiches 1 à 7 malgré la grosse journée de commits — le splash garde ses 5 500 ms (`splash_page.dart:85`, le mur d'ouverture `5acdfff` s'y ajoute sans le raccourcir), et le retour du lecteur est toujours en `go('/category/…')` hors `viaLancement`. À noter : les bugs corrigés le 28/08 (clavier du chat qui survivait à la navigation `450e54d`, séance du programme qui continuait après « Arrêter le programme » `d387539`) n'avaient jamais été listés ici — trouvés et réglés dans la même session.
> 🔎 **Point de contrôle du 28/09/2026** (v1.0.28+39, dépôt unique) : bugs 1 à 7 re-vérifiés dans le code — **tous toujours ouverts, même état qu'au 28/08** (artwork à chemin fixe `quieto_artwork.png` et écriture non protégée, `audio_handler.dart:160-161` ; retour du lecteur en `go(categoryPath)` hors `viaLancement`, `player_page.dart:83-87` ; splash à 5 500 ms, `splash_page.dart:85` ; `savePosition` / `lastPosition` jamais appelés hors du modèle ; `saveProgress` loggé mais avalé, `storage_service.dart:274-281` ; `dispose()` du handler sans appelant). Les numéros de ligne des fiches ci-dessous datent du 24/06 : se fier à ceux de cette note. Le rapport de nuit est maintenant à `../../Quieto IA/rapports-nuit/rapport-nuit-1.md` (l'app est passée dans `Quieto/app/` le 26/09). Quatre bugs trouvés et réglés les 26 et 28/09 sont consignés dans la section suivante.

---

## ✅ Réglés les 26 et 28/09/2026 (jamais listés ici avant)
- **L'accueil de l'onboarding plantait à chaque appel** (serveur, du 02/09 au 26/09) : `accueilOnboarding` levait `ReferenceError: Cannot access 'texte' before initialization` — une variable locale `texte` masquait la fonction `texte()` des bornes. Tous les nouveaux utilisateurs recevaient l'accueil de repli de l'app. **Résolu : commit `380a08a`** (variable renommée `contenu`), déployé le 26/09.
- **Signes bizarres en fin de bulle** (« Désolée◌ੑ ») : Luna lâche parfois un jeton d'une autre écriture. **Résolu : commit `7cb12eb`**, filet serveur `sansEcritureEtrangere` (Voix, accueil, programme). À suivre avec le signal Vigie `ecritureEtrangere`.
- **Phrase creuse après un « salut »** (« Salut ! Je te laisse reprendre le fil quand tu veux ») : **résolu : commit `7cb12eb`** (règle, exemple du prompt et `consigneAccueil`).
- **Page Louane saccadée en permanence** (voile introduit entre la 1.0.23 et la 1.0.26, encore là en 1.0.27) : 14 couches de `BackdropFilter` dans le voile de l'en-tête. **Résolu : commit `7cb12eb`** (6 couches), part avec la 1.0.28.

## ⚠️ Vu le 28/09/2026, pas encore corrigé
- **`AppConstants.appVersion` est resté à `1.0.25`** (`lib/core/config/app_constants.dart:6`) alors que `pubspec.yaml` est à `1.0.28+39`. La Vigie, la carte d'avis et le mail « Nous contacter » annoncent donc « 1.0.25 » pour les builds 1.0.26, 1.0.27 et 1.0.28 : impossible de comparer ces versions entre elles dans la Vigie. **Fix** : aligner la constante à chaque bump (le commentaire du fichier le demande déjà). **Sévérité** : moyenne pour la mesure, nulle pour l'utilisateur.
- **`flutter_tts` déclaré mais plus utilisé** : le paquet est dans `pubspec.yaml`, aucun fichier de `lib/` ne l'importe (mode vocal annulé le 22/09). **Fix** : le retirer de `pubspec.yaml`. **Sévérité** : très faible.

---

## ✅ Déjà réglé (24/06/2026)
- **Garde-fou paywall** : `_devUnlockPremium` ne peut plus partir en release par erreur (`!kReleaseMode`) → `lib/core/services/storage_providers.dart`
- **Nettoyage** : `ios/build/` sorti du suivi git, `.DS_Store` supprimés, ~1,2 Go de cache libérés, secrets Firebase protégés (gitignore).

---

## 🔧 À corriger (par priorité)

### 1. Mauvaise image sur l'écran verrouillé (+ plantage rare)
- **Pour l'utilisateur** : en enchaînant 2 séances, l'écran verrouillé peut afficher la pochette de la séance précédente ; si l'écriture du fichier échoue, la séance peut planter.
- **Technique** : artwork écrit dans un fichier temp à chemin fixe (`quieto_artwork.png`), sans try/catch.
- **Fichier** : `lib/features/player/data/audio_handler.dart` (~126-149)
- **Fix** : nom de fichier unique par séance (`quieto_artwork_<id>.png`) + try/catch (omettre l'image plutôt que crasher).
- **Sévérité** : moyen-faible
- *Vérifié 12/08/2026 : partiellement atténué — le **chargement** de l'artwork est maintenant dans un try/catch (fallback logo), mais l'**écriture** (`tempFile.writeAsBytes`) reste non protégée et le chemin est toujours fixe (`quieto_artwork.png`).*

### 2. Bouton « retour » du lecteur incohérent
- **Pour l'utilisateur** : une séance Express lancée depuis l'accueil renvoie vers un écran jamais visité au lieu de l'accueil ; casse le retour Android.
- **Technique** : `go('/category/<id>')` systématique au lieu de revenir en arrière.
- **Fichier** : `lib/features/player/presentation/player_page.dart` (~142-147)
- **Fix** : `context.canPop() ? context.pop() : context.go(home)` (pattern déjà présent ailleurs dans le code).
- **Sévérité** : faible
- *Vérifié 12/08/2026 : toujours ouvert pour le cas général — seul le cas « venu du chat Louane » (`viaLancement`) fait maintenant un `pop()` ; sinon, `go('/category/<id>')` systématique.*

### 3. Écran de démarrage trop long
- **Pour l'utilisateur** : splash de 5,5 s fixes à chaque ouverture, même quand l'app est prête → friction / décrochage.
- **Fichier** : `lib/app/splash_page.dart` (~85-93)
- **Fix** : réduire (~2,5-3 s) ou rendre conditionnel. ⚠️ **Choix de goût — à valider avec Paul.**
- **Sévérité** : faible (UX/rétention)

### 4. Date interne mal gérée (piège futur pour les « streaks »)
- **Pour l'utilisateur** : aucun impact aujourd'hui, mais fausserait une future logique de jours consécutifs de méditation.
- **Technique** : `lastSessionDate` écrasée à chaque flush (~10 s) au lieu de marquer la fin de séance.
- **Fichier** : `lib/core/models/user_progress_model.dart` (~62-68)
- **Fix** : ne mettre à jour la date que dans `markCompleted`.
- **Sévérité** : faible (latent)

### 5. Reprise de lecture non branchée (code mort)
- **Pour l'utilisateur** : une longue séance interrompue redémarre toujours à zéro.
- **Technique** : `savePosition` / `lastPosition` existent et sont sérialisés, mais jamais appelés.
- **Fichier** : `lib/core/models/user_progress_model.dart` (~70-74)
- **Fix** : trancher — soit câbler la reprise (vraie fonctionnalité), soit supprimer le code mort. ⚠️ **Décision produit.**
- **Sévérité** : faible

### 6. Sauvegardes qui avalent les erreurs en silence
- **Pour l'utilisateur** : en cas d'échec disque rare, quelques secondes méditées perdues sans signal.
- **Technique** : `saveProgress` (et autres setters) ignorent les échecs → le retry est neutralisé.
- **Fichier** : `lib/core/services/storage_service.dart` (~77-84)
- **Fix** : retourner un booléen de succès ou rethrow ciblé.
- **Sévérité** : faible
- *Vérifié 12/08/2026 : l'échec est maintenant loggé (`debugPrint` dans le try/catch de `saveProgress`) mais toujours avalé — pas de signal au code appelant.*

### 7. Lecteur audio jamais libéré (fuite bénigne)
- **Technique** : `dispose()` du handler jamais appelé → le dernier AudioPlayer reste vivant tant que l'app tourne.
- **Fichier** : `lib/features/player/data/audio_handler.dart` (~335-343)
- **Fix** : brancher le nettoyage sur le cycle de vie. ⚠️ **Bénin — à faire prudemment** (risque d'introduire un vrai bug pour peu de gain).
- **Sévérité** : très faible

### 8. Lien cassé dans la doc — ✅ RÉSOLU (12/08/2026)
- **Technique** : `QUIETO.md` renvoie à `SEANCES.md`, qui n'existe pas.
- **Fix** : corriger le lien vers la vraie source (`lib/features/explore/data/explore_repository.dart`).
- **Sévérité** : trivial
- *Résolu par la réécriture de `QUIETO.md` (commit `28ab240`) : le doc pointe désormais vers `explore_repository.dart` et précise que l'ancien `SEANCES.md` n'existe plus.*

---

## 🕒 Plus tard (risqué — avec précaution)
- **Dépôt git lourd (~375 Mo)** : 37 vieux fichiers `.mp3` (audios déplacés sur Firebase) traînent dans l'historique git. Nettoyable, mais nécessite une **réécriture d'historique** — risqué si le repo est partagé. À faire seulement en solo + sauvegarde complète.

---
*Trouvé par l'équipe d'agents de nuit, 24/06/2026. 4 autres « bugs » ont été vérifiés puis écartés (faux positifs). Pour relancer une nuit d'agents : dossier `Quieto IA/`.*
