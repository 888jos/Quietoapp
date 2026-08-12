# 🐛 Bugs à corriger — Quieto

> Backlog des bugs trouvés par l'équipe d'agents de nuit (24/06/2026) et **vérifiés**.
> Rapport complet : `../Quieto IA/rapports-nuit/rapport-nuit-1.md`.
> ⚠️ **Aucun n'est urgent** — rien de cassé en production. À traiter quand tu veux.
> 🔎 **Point de contrôle du 12/08/2026** : chaque bug re-vérifié dans le code. Bugs 1 à 7 : **toujours ouverts** (nuances notées en italique dans les fiches). Bug 8 : **résolu**.

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
