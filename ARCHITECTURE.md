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
    │   │       ├── category_bubble.dart
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
    ├── profile/
    └── paywall/
```

## Stack technique

| Rôle | Package |
|---|---|
| State management | `flutter_riverpod ^2.5.1` |
| Navigation | `go_router ^14.0.0` |
| Audio | `just_audio ^0.9.36` |
| Stockage local | `shared_preferences ^2.2.0` |
| Achats in-app | `purchases_flutter ^7.0.0` (RevenueCat) |
| Icônes | `iconsax_flutter ^1.0.0` |

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
3. **Navigation centralisée** — toutes les routes sont définies dans `app/router.dart`. On utilise `context.go()` / `context.push()` avec les constantes `AppRoutes`.
4. **ConsumerWidget** — utiliser `ConsumerWidget` (pas `StatefulWidget` + `ref`) pour éviter les rebuilds inutiles.
5. **Try-catch obligatoire** — toute opération async est enveloppée dans un try-catch.

## Modèles de données

### CategoryModel
Regroupe un ensemble de `SessionModel`. Champs clés : `isPremium` (bool — accès abonnement requis), `isNew` (bool — badge "New !"), `totalMinutes` (calculé).

### SessionModel
Unité de contenu : une séance de méditation avec son fichier audio, sa durée, et son statut premium.

### UserProgressModel
Suivi de la progression utilisateur : sessions complétées, positions sauvegardées, total de minutes. Sérialisé en JSON dans SharedPreferences.

## Navigation

```
/ (splash)  ──► /onboarding
            └─► /home (shell)
                  ├─ /home
                  ├─ /explore
                  └─ /profile

/player/:sessionId   (hors shell, plein écran)
/paywall             (hors shell)
/category/:categoryId  (hors shell — CategoryDetailPage)
```
