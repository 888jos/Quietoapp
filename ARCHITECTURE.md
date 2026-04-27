# Architecture — Quieto

## Vue d'ensemble

Quieto suit une **architecture feature-first** avec une séparation stricte entre logique métier et UI.

```
lib/
├── app/              # Racine de l'app (routing, shell de navigation)
├── core/             # Partagé entre toutes les features
│   ├── config/       # Constantes globales (AppConstants, AppRoutes)
│   ├── models/       # Entités de données (immuables)
│   ├── services/     # Services techniques (StorageService, storage_providers)
│   ├── theme/        # Design system (couleurs, typographie, thème)
│   └── ui/           # Composants réutilisables (AppButton, AppCard…)
└── features/         # Domaines métier
    ├── onboarding/
    │   ├── presentation/
    │   │   ├── onboarding_page.dart
    │   │   └── widgets/
    │   │       ├── intro_slide.dart
    │   │       ├── question_slide.dart
    │   │       ├── text_input_slide.dart
    │   │       └── progress_bar.dart
    │   └── onboarding_providers.dart
    ├── home/
    │   ├── data/
    │   │   └── home_repository.dart
    │   ├── presentation/
    │   │   ├── home_page.dart
    │   │   └── widgets/
    │   │       ├── featured_session_card.dart
    │   │       └── category_list_card.dart
    │   └── home_providers.dart
    ├── explore/
    │   ├── data/
    │   │   └── explore_repository.dart
    │   ├── presentation/
    │   │   ├── explore_page.dart
    │   │   ├── category_detail_page.dart
    │   │   └── widgets/
    │   │       └── session_card.dart
    │   └── explore_providers.dart
    ├── player/
    │   ├── data/
    │   │   ├── player_repository.dart
    │   │   └── audio_handler.dart     # QuietoAudioHandler (BaseAudioHandler + SeekHandler)
    │   ├── presentation/
    │   │   ├── preparation_page.dart  # Écran de préparation (5s timer + fade) avant chaque séance
    │   │   ├── player_page.dart
    │   │   └── widgets/
    │   │       └── mini_player.dart   # Mini player persistant (au-dessus de la bottom nav)
    │   └── player_providers.dart      # activeSessionIdProvider (StateProvider<String?>)
    ├── profile/
    │   ├── presentation/
    │   │   └── profile_page.dart
    │   └── profile_providers.dart
    └── paywall/
```

## Stack technique

| Rôle | Package |
|---|---|
| State management | `flutter_riverpod ^2.5.1` |
| Navigation | `go_router ^14.0.0` |
| Audio | `just_audio ^0.9.36` |
| Audio background | `audio_service ^0.18.0` |
| Stockage local | `shared_preferences ^2.2.0` |
| Achats in-app | `purchases_flutter ^9.14.0` + `purchases_ui_flutter ^9.14.0` (RevenueCat) |
| Icônes | `iconsax_flutter ^1.0.0` |
| Liens URL | `url_launcher ^6.3.0` |

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

### UserProgressModel
Suivi de la progression utilisateur : sessions complétées, positions sauvegardées, total de minutes. Sérialisé en JSON dans SharedPreferences.

## Navigation

```
/ (splash)  ──► /onboarding ──► /onboarding-loading ──► /onboarding-ready ──► /paywall (PaywallView RevenueCat, onDismiss → /home) ──► /home
            └─► StatefulShellRoute (HomeShell + bottom nav)
                  ├─ branch 0 : /home    → HomePage    (stack isolée)
                  ├─ branch 1 : /explore → ExplorePage (stack isolée)
                  └─ branch 2 : /profile → ProfilePage (stack isolée)

/preparation/:sessionId (hors shell — context.push depuis session card → fade 300ms → /player)
/player/:sessionId      (hors shell — context.push depuis preparation ou mini player)
/paywall                (hors shell — context.go depuis onboarding / context.push depuis profil)
/category/:categoryId   (hors shell — context.push, retour possible)
```

### Choisir le bon type de navigation

Avant d'ajouter une route, se poser ces questions :

| Situation | Type à utiliser |
|---|---|
| Page avec retour arrière (detail, player, modal) | `GoRoute` + `context.push()` |
| Changement de tab navbar | `shell.goBranch(index)` |
| Redirection sans retour (splash → home) | `context.go()` |
| Nouveau groupe de tabs avec layout partagé | `StatefulShellRoute` |
