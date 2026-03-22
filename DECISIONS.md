# Décisions techniques — Quieto

## ADR-001 — Riverpod pour le state management

**Décision** : `flutter_riverpod ^2.5.1`

**Pourquoi** : Riverpod est compilé et type-safe contrairement à Provider. Il permet l'injection de dépendances propre (overrides dans ProviderScope) et évite les BuildContext dans les couches non-UI. La famille `StateNotifierProvider.family` couvre parfaitement le cas du player par sessionId.

**Alternative rejetée** : Bloc — trop verbeux pour une app de taille MVP.

---

## ADR-002 — GoRouter pour la navigation

**Décision** : `go_router ^14.0.0` avec `StatefulShellRoute.indexedStack` pour la bottom navbar.

**Pourquoi** : Gestion déclarative des routes avec deep linking natif. Support officiel Flutter. `StatefulShellRoute` donne une stack de navigation isolée par tab — le scroll, l'état et l'historique de chaque tab sont préservés quand on change d'onglet.

**Alternative rejetée** : `auto_route` — génération de code non nécessaire à ce stade.

**Migration** : Démarré avec `ShellRoute` (stack partagée entre tous les tabs). Migré vers `StatefulShellRoute.indexedStack` pour isoler les stacks et conserver l'état par tab (ADR-012).

**Règle pour toute nouvelle route** : Avant d'ajouter une route, se demander quel type utiliser pour une UX optimale :
- `GoRoute` → page simple sans layout persistant
- `StatefulShellRoute` → tabs avec bottom nav, état conservé par tab
- `context.go()` → changement de tab (remplace la stack)
- `context.push()` → navigation vers une page avec retour possible (player, detail, paywall)

---

## ADR-003 — Contenu audio statique (pas de Firebase Storage)

**Décision** : Les fichiers audio sont embarqués dans `assets/audio/`, organisés en sous-dossiers par catégorie.

**Structure** : `assets/audio/<categorie>/<categorie>_<slug>.mp3` (ex. `stress/stress_body_scan.mp3`). Chaque catégorie a son propre sous-dossier déclaré dans `pubspec.yaml`.

**Pourquoi** : Simplicité maximale pour le MVP. Zéro infrastructure à gérer, fonctionnel hors-ligne par défaut. Les sous-dossiers facilitent la gestion des assets quand le catalogue grandit.

**Évolution prévue** : Migration vers Firebase Storage (remote URL) avec cache local via `just_audio` quand le catalogue grandira.

---

## ADR-004 — SharedPreferences pour la persistence locale

**Décision** : `shared_preferences ^2.2.0` avec `StorageService` wrapper.

**Pourquoi** : Suffisant pour la progression utilisateur (JSON sérialisé). Hive ou Isar seraient over-engineered pour les données MVP.

**Évolution prévue** : Migration vers Isar si le volume de données (historique, favoris) le justifie.

---

## ADR-005 — RevenueCat pour les achats in-app

**Décision** : `purchases_flutter ^7.0.0` (RevenueCat)

**Pourquoi** : Abstraction cross-platform (iOS StoreKit + Android Billing) avec tableau de bord analytics. Évite la complexité de gérer les webhooks de validation de reçus manuellement.

**Configuration nécessaire** : Remplacer les placeholders dans `AppConstants` par les vraies clés RevenueCat.

---

## ADR-006 — Dark theme uniquement

**Décision** : Pas de mode clair, `ThemeData` unique.

**Pourquoi** : Cohérence visuelle forte avec la palette forêt/sage. Le mode clair dégraderait l'expérience. Décision produit assumée.

---

## ADR-007 — Architecture feature-first

**Décision** : Organisation par domaine métier, pas par type de fichier.

**Pourquoi** : Plus scalable que layer-first quand le nombre de features grandit. Chaque feature est auto-contenue et peut être développée / supprimée indépendamment.

---

## ADR-008 — Système free/premium par catégorie entière

**Décision** : Une seule catégorie gratuite (🧘 Découverte). Toutes les autres sont premium. Pas de cadenas — le paywall s'affiche au tap.

**Pourquoi** : Modèle plus simple qu'un mix sessions gratuites/premium par catégorie. La catégorie Découverte offre une vraie valeur introductive aux non-abonnés sans fragmenter le contenu premium.

**Implémentation** : `categoryRouteProvider(categoryId)` dans `explore_providers.dart` calcule la destination (detail ou paywall). Zéro logique dans les widgets — ils lisent seulement le provider et appellent `context.push`. `subscriptionProvider` dans `storage_providers.dart` lit SharedPreferences ; sera remplacé par RevenueCat (ADR-005).

---

## ADR-009 — Badge "New !" sur Actualité uniquement

**Décision** : `CategoryModel.isNew` (bool) contrôle l'affichage du badge. Seule la catégorie Actualité a `isNew: true` pour le MVP. Le badge s'affiche sur deux widgets :
- `FeaturedSessionCard` (home "Priorité du moment") — `Stack` + `Positioned(top:-8, right: spacingSm)`
- `CategoryListCard` (liste verticale) — `Stack(clipBehavior: Clip.none)` + `Positioned(bottom:18, right:0)` flottant au-dessus du compteur de séances

Note : `CategoryBubble` (scroll horizontal) supprimé — le scroll horizontal de la home a été retiré au profit d'un header simplifié.

**Pourquoi** : Mettre en avant le contenu le plus actuel sur tous les points d'entrée de la home. Le badge est un signal éditorial, pas un indicateur technique.

---

## ADR-011 — Onboarding : flow en 6 étapes avec questions de personnalisation

**Décision** : L'onboarding comporte 6 slides gérées par un `PageController` dans `OnboardingPage` (ConsumerStatefulWidget).
- Slides 0-1 : intro animée avec `IntroSlide` (emoji + titre + sous-titre).
- Slides 2-4 : 3 questions à choix unique (`QuestionSlide`) — objectif principal, moment préféré, état émotionnel.
- Slide 5 : saisie du prénom (`TextInputSlide`).
- Pas de bouton "Passer" — le flow est obligatoire.
- "Commencer" sur la dernière slide → sauvegarde réponses + prénom + `setOnboardingDone()` + **`context.go('/paywall')`** (le paywall s'affiche immédiatement après l'onboarding).
- `_SplashDecider` (router) est un `ConsumerStatefulWidget` qui lit `storageServiceProvider.isOnboardingDone` pour router vers `/onboarding` ou `/home` au démarrage.

**État** : `OnboardingNotifier` (`StateNotifierProvider.autoDispose`) stocke `answers` (Map<String, String>) et `firstName`. Réponses persistées dans `SharedPreferences` via `StorageService.saveOnboardingAnswers` (clé `prefOnboardingAnswers`, JSON encodé).

**Pourquoi** : Collecter le contexte utilisateur dès le départ pour personnaliser l'expérience future (objectif, timing, humeur, prénom). Zéro logique dans les widgets — tout passe par le notifier.

---

## ADR-012 — Migration ShellRoute → StatefulShellRoute

**Décision** : La bottom navbar utilise `StatefulShellRoute.indexedStack` avec 3 branches (Home, Explore, Profile).

**Pourquoi** : `ShellRoute` partage un seul navigator entre tous les tabs — changer de tab détruisait l'état de la page précédente et pouvait créer des empilements inattendus. `StatefulShellRoute` donne une stack indépendante par tab et conserve le scroll, les données chargées et l'historique de navigation de chaque onglet.

**Implémentation** : `HomeShell` reçoit un `StatefulNavigationShell` (au lieu d'un `Widget child`). La navbar appelle `shell.goBranch(index)` avec `initialLocation: index == shell.currentIndex` pour permettre un double-tap sur un tab de revenir à la racine du tab.

---

## ADR-013 — UX Paywall : bouton fermer différé (3 secondes)

**Décision** : Le paywall n'affiche pas de bouton retour immédiat. Un bouton ✕ (`close_rounded`) apparaît après 3 secondes via un `Timer` + `AnimatedOpacity`. La fermeture appelle `context.go(AppRoutes.home)`.

**Pourquoi** : Force l'utilisateur à lire les avantages Premium au moins 3 secondes avant de pouvoir fermer — pattern paywall classique (App Store, Duolingo, etc.). Le délai est court mais suffisant pour créer de l'intention.

**Implémentation** : `_closeTimer` dans `ConsumerStatefulWidget`, dispose propre du timer. `_dismiss()` utilise `context.go` (pas `context.pop`) car le paywall peut être la racine de la stack (ex. arrivée depuis onboarding).

---

## ADR-014 — Flag de développement `_devUnlockPremium`

**Décision** : `const bool _devUnlockPremium = true` dans `storage_providers.dart`. Quand `true`, `subscriptionProvider` retourne `true` sans lire SharedPreferences.

**Pourquoi** : Pendant le développement, le paywall bloque l'accès aux features premium. Ce flag permet de tester les catégories premium sans souscrire ni mocker RevenueCat.

**Règle** : Remettre à `false` avant toute release. Ne jamais committer `true` sur `main` en production.

---

## ADR-015 — audio_service pour la lecture en arrière-plan

**Décision** : `audio_service ^0.18.0` avec `QuietoAudioHandler` (`BaseAudioHandler` + `SeekHandler`) dans `lib/features/player/data/audio_handler.dart`.

**Pourquoi** : `just_audio` seul ne permet pas la lecture audio quand l'app est en arrière-plan ni l'affichage des contrôles sur l'écran de verrouillage / notification Android. `audio_service` wrappe le player dans un service natif (foreground service Android, background audio iOS) tout en restant compatible avec `just_audio`. La logique d'affichage de la notification (MediaItem, PlaybackState) est encapsulée dans `QuietoAudioHandler` — zéro fuite dans les widgets ou les providers.

**Architecture** : `QuietoAudioHandler` prend un `StorageService` en paramètre (injection de dépendance). Un `audioHandlerProvider` (Provider Riverpod) maintient une instance singleton du handler et la dispose proprement. `PlayerNotifier` délègue toute la lecture au handler et écoute ses streams — l'API publique (`togglePlayPause`, `seekTo`, `skipForward`, `skipBackward`) reste inchangée.

**Plateformes** :
- iOS : `UIBackgroundModes > audio` ajouté dans `Info.plist`
- Android : service `AudioService` + receiver `MediaButtonReceiver` + permissions `FOREGROUND_SERVICE` et `FOREGROUND_SERVICE_MEDIA_PLAYBACK` ajoutés dans `AndroidManifest.xml`

**Alternative rejetée** : Rester sur `just_audio` seul — ne supporte pas le background audio de façon fiable cross-platform sans le wrapper `audio_service`.

---

## ADR-010 — Curation de la home page

**Décision** : La home est structurée en 3 blocs :
- Header : logo + greeting RichText animé (fade in 600ms). `ConsumerStatefulWidget` pour l'`AnimationController`.
- "Priorité du moment" (`FeaturedSessionCard`) : Découverte de la méditation (🧘, catégorie gratuite, 3 séances).
- Liste verticale "Catégories disponibles" : toutes les catégories avec emoji, nom, description, nb séances.

**Pourquoi** : Le scroll horizontal de bulles a été supprimé — redondant avec la liste verticale et ajoutait de la complexité UI sans valeur ajoutée. La home reste focalisée sur deux points d'entrée clairs. La logique de curation est dans `categoriesProvider` (`home_providers.dart`) — zéro logique dans les widgets.

---

## ADR-016 — Écran de préparation avant chaque séance

**Décision** : Une route `/preparation/:sessionId` s'intercale entre la session card et le player. `PreparationPage` (`ConsumerStatefulWidget`) affiche le titre de la séance, une icône lotus, des messages d'installation, et une barre de progression qui se remplit sur 5 secondes.

**Comportement** :
- Tap n'importe où → `_fadeController.reverse()` (300ms) puis `context.push('/player/:id')`
- Auto après 5s → même fade via `_progressController.addStatusListener`
- `_navigated` flag pour éviter la double navigation

**Pourquoi** : Créer une transition intentionnelle entre l'UI de l'app et la méditation. L'utilisateur a 5 secondes pour s'installer sans être précipité dans l'audio. Tap disponible pour ceux qui sont déjà prêts.

**Implémentation** : Deux `AnimationController` (`_progressController` 5s, `_fadeController` 300ms), tous deux disposés proprement dans `dispose()`. Zéro logique métier dans le widget.

---

## ADR-017 — RichText pour le greeting home plutôt que deux Text séparés

**Décision** : Le greeting du header home utilise un seul `RichText` avec deux `TextSpan` séparés par `\n` : ligne 1 "Salut [prénom]," (w700, textPrimary), ligne 2 "on fait quoi aujourd'hui ?" (w400, textMuted).

**Pourquoi** : Deux `Text` séparés créaient un écart vertical visible et rendaient difficile l'alignement entre les deux lignes. `RichText` garantit un rendu cohérent sur une seule passe de layout, avec un interligne natif contrôlé par Flutter. L'approche est aussi plus légère — un seul widget au lieu de deux dans l'arbre.
