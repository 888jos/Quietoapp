# Architecture — Quieto

> Maj 12/08/2026 — ajout des features Louane & Parcours, nav 3 onglets (Accueil / Louane / Profil), stack et navigation resynchronisées avec le code (v1.0.15+22).
> Maj 26/08/2026 (v1.0.20+29) — onboarding resynchronisé (écran « compréhension », respiration avant Apple Santé), shaders GPU de la home (`shaders/aurora.frag`, `stardust.frag`), bandeaux de catégorie (`assets/images/categories/`), plus aucun outil de dev dans l'app (commit `9e82c22` : fini `?demo=1`, `premium_force_dev`, `avancerJourDev()`).

## Vue d'ensemble

Quieto suit une **architecture feature-first** avec une séparation stricte entre logique métier et UI.

```
lib/
├── app/              # Racine : router.dart (routes + AppRoutes), home_shell.dart (bottom nav), splash, transitions
├── core/             # Partagé entre toutes les features
│   ├── config/       # AppConstants, RevenueCatConfig (AppRoutes vit dans app/router.dart)
│   ├── models/       # CategoryModel, SessionModel, ParcoursModel, UserProgressModel
│   ├── services/     # StorageService, AuthService, HealthService, NotificationService, AmbientMusic, VigieService
│   ├── theme/        # Design system (couleurs, typographie, thème, transitions fondu)
│   └── ui/           # AppButton, AppCard, AppScaffold, StarryBackground, boutons de connexion…
└── features/         # Domaines métier
    ├── onboarding/   # V2 conversion : connexion (Apple/Google), questions, compréhension
    │                 #   (Louane résume — loading/ready restent en repli), respiration (breath),
    │                 #   santé (iOS), trust — + data/weekly_program.dart, data/accueil_louane.dart
    ├── home/         # Accueil : home_page + widgets (night_sky_header, glowing_moon, parcours_card…)
    ├── louane/       # Compagnonne IA : louane_page (chat), louane_avatar (dessiné en code),
    │                 #   carte_seance_louane, rituel sommeil, data/ (repository, messages, heure de Paris)
    ├── parcours/     # Programme 7 jours créé par Louane : parcours_creation_page (le moment « wow »),
    │                 #   parcours_page, constellation d'étoiles, carte de partage
    ├── explore/      # Catalogue : data/explore_repository.dart (LES 35 séances),
    │                 #   category_detail_page — il n'y a PLUS de page « Explorer » dans la nav
    ├── player/       # preparation_page, lancement_page (animation Louane), player_page,
    │                 #   mini_player, data/audio_handler.dart (QuietoAudioHandler)
    ├── profile/      # profile_page (stats, réglages, compte)
    └── paywall/      # Paywall Flutter maison : paywall_page + paywall_screen (offres via RevenueCat)
```

## Stack technique

| Rôle | Package |
|---|---|
| State management | `flutter_riverpod ^2.5.1` |
| Navigation | `go_router ^14.0.0` |
| Audio | `just_audio ^0.9.36` |
| Audio background | `audio_service ^0.18.0` |
| Stockage local | `shared_preferences ^2.2.0` |
| Achats in-app | `purchases_flutter ^9.14.0` + `purchases_ui_flutter ^9.0.0` (RevenueCat) |
| Firebase | `firebase_core`, `firebase_auth`, `firebase_app_check`, `cloud_functions` (Louane, trace, genererParcours) |
| Comptes | `google_sign_in`, `sign_in_with_apple` (+ `crypto`) |
| Santé | `health ^13.3.1` (Apple Santé / Health Connect) |
| Notifications | `flutter_local_notifications ^22.0.0` + `timezone` / `flutter_timezone` |
| Voix (Louane) | `speech_to_text ^7.4.0`, `flutter_tts ^4.2.5` |
| Partage | `share_plus ^11.0.0` + `path_provider` (version contrainte — voir le commentaire dans `pubspec.yaml`) |
| Icônes | `iconsax_flutter ^1.0.0`, `material_symbols_icons` |
| Liens URL | `url_launcher ^6.3.0` |

(maj 12/08/2026 — liste resynchronisée avec `pubspec.yaml`)

## Flux de données

```
UI (ConsumerWidget)
  └── lit Provider / StateNotifier
        └── Repository (logique d'accès aux données)
              └── Source (assets statiques, SharedPreferences, audio)
```

## Règles d'architecture

1. **Zéro hardcode** — toutes les couleurs viennent de `AppColors` (`background`, `cardSurface`, `accent`, `textPrimary`…), tous les styles de `AppTextStyles`, toutes les valeurs de `AppConstants`.
2. **Zéro logique dans les widgets** — les widgets lisent des providers et affichent. Toute logique va dans un `Notifier` ou un `Repository`.
3. **Navigation centralisée** — toutes les routes sont définies dans `app/router.dart`. On utilise `context.go()` / `context.push()` avec les constantes `AppRoutes`. Avant d'ajouter une route, choisir le bon type (`GoRoute`, `StatefulShellRoute`, `context.go` vs `context.push`) selon l'UX voulue — voir ADR-002 et ADR-012.
4. **ConsumerWidget par défaut** — utiliser `ConsumerWidget` pour les widgets sans état local. Utiliser `ConsumerStatefulWidget` uniquement quand un `AnimationController`, un `Timer`, ou un cycle de vie (`initState`/`dispose`) est nécessaire.
5. **Try-catch obligatoire** — toute opération async est enveloppée dans un try-catch.
6. **Assets en ASCII pur** — les noms de fichiers dans `assets/audio/` et `assets/images/sessions/` ne contiennent ni accents ni espaces (problème NFD/NFC sur macOS, voir ADR-024).
7. **Haptic ciblé** — les vibrations ne sont posées que sur les actions à valeur (validation, navigation principale, contrôles audio), pas sur les retours arrière ou éléments décoratifs (voir ADR-022).

## Modèles de données

### CategoryModel
Regroupe un ensemble de `SessionModel`. Champs clés : `isPremium` (bool — accès abonnement requis), `isNew` (bool — badge "New !"), `totalMinutes` (calculé).

### SessionModel
Unité de contenu : une séance de méditation avec son fichier audio (`audioFile` — chemin ASCII relatif sous `assets/audio/`), son image de couverture optionnelle (`imageFile` — chemin sous `assets/images/sessions/<categorie>/`), sa durée, et son statut premium.

### ParcoursModel (ajouté — maj 12/08/2026)
Le programme 7 jours créé par Louane : 7 `ParcoursJour` (une séance du catalogue par jour + un mot d'elle). Généré par la Cloud Function `genererParcours`, persisté en SharedPreferences ; les infos de séance (titre, durée, premium) sont résolues côté serveur et stockées dans le modèle pour que l'affichage ne casse jamais si le catalogue bouge.

### UserProgressModel
Suivi de la progression utilisateur : sessions complétées, positions sauvegardées, total de minutes. Sérialisé en JSON dans SharedPreferences.

## Navigation

```
/ (splash) ──► /onboarding-connexion (compte Apple/Google, jamais bloquant)
           ──► /onboarding (questions) ──► /onboarding-comprehension (Louane résume ce qu'elle a compris)
           ──► /onboarding-breath (respiration) ──► /onboarding-sante (iOS uniquement) ──► /onboarding-trust
           ──► /paywall ──► /home
           (routes /onboarding-loading et /onboarding-ready : anciennes transitions, gardées en repli)
           └─► StatefulShellRoute (HomeShell + bottom nav « Accueil / Louane / Profil »)
                 ├─ branch 0 : /home    → HomePage   (stack isolée)
                 ├─ branch 1 : /louane  → LouanePage (stack isolée)
                 └─ branch 2 : /profile → ProfilePage (stack isolée)

/preparation/:sessionId (hors shell — fade avant la séance → /player)
/lancement/:sessionId   (hors shell — animation « je te la lance » quand Louane lance une séance)
/player/:sessionId      (hors shell — depuis preparation, lancement ou mini player)
/parcours/creation      (hors shell — génération du programme 7 jours, le moment « wow »)
/parcours               (hors shell — l'écran du programme)
/paywall                (hors shell — `?from=premium&src=…` : la Vigie note la surface d'origine)
/category/:categoryId   (hors shell — context.push, retour possible)
```
(maj 12/08/2026 — routes resynchronisées avec `app/router.dart` ; l'onglet Explorer a laissé sa place à Louane)
(maj 26/08/2026 — ordre réel de l'onboarding : compréhension puis respiration puis Santé ; le mode `?demo=1` de `/parcours/creation` n'existe plus, retiré avec les outils de dev — commit `9e82c22`)

### Choisir le bon type de navigation

Avant d'ajouter une route, se poser ces questions :

| Situation | Type à utiliser |
|---|---|
| Page avec retour arrière (detail, player, modal) | `GoRoute` + `context.push()` |
| Changement de tab navbar | `shell.goBranch(index)` |
| Redirection sans retour (splash → home) | `context.go()` |
| Nouveau groupe de tabs avec layout partagé | `StatefulShellRoute` |
