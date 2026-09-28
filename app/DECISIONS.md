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

**Décision** : `purchases_flutter ^9.14.0` (RevenueCat)

**Pourquoi** : Abstraction cross-platform (iOS StoreKit + Android Billing) avec tableau de bord analytics. Évite la complexité de gérer les webhooks de validation de reçus manuellement.

**Configuration** : Clé API isolée dans `lib/core/config/revenue_cat_config.dart`. En mode debug, `StoreKitVersion.storeKit2` est forcé pour permettre les tests sur simulateur via le fichier `ios/Configuration.storekit`. En production, RevenueCat sélectionne automatiquement la version StoreKit optimale. Le flag `PURCHASES_HYBRID_COMMON_USE_SK1` a été retiré du Podfile pour ne plus bloquer SK2.

**Tests simulateur** : `ios/Configuration.storekit` déclare deux abonnements (`quieto_premium_monthly` à 8.99€/mois, `quieto_premium_yearly` à 59.99€/an). Le scheme Xcode (`Runner.xcscheme`) est configuré pour charger ce fichier en Debug via `storeKitConfigurationFileReference`.

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

## ADR-011 — Onboarding : flow en 7 étapes avec questions émotionnelles

**Décision** : L'onboarding comporte 7 slides gérées par un `PageController` dans `OnboardingPage` (ConsumerStatefulWidget).
- Slides 0-1 : intro animée avec `IntroSlide` (emoji + titre + sous-titre).
- Slides 2-5 : 4 questions émotionnelles à choix unique (`QuestionSlide`) — frein au bien-être, durée du ressenti, domaine affecté, moment préféré pour méditer.
- Slide 6 : saisie du prénom (`TextInputSlide`).
- Pas de bouton "Passer" — le flow est obligatoire.
- "Commencer" sur la dernière slide → sauvegarde réponses + prénom + `setOnboardingDone()` + **`context.go('/paywall')`** (le paywall s'affiche immédiatement après l'onboarding).
- `_SplashDecider` (router) est un `ConsumerStatefulWidget` qui lit `storageServiceProvider.isOnboardingDone` pour router vers `/onboarding` ou `/home` au démarrage.

**État** : `OnboardingNotifier` (`StateNotifierProvider.autoDispose`) stocke `answers` (Map<String, String>, clés q1–q4) et `firstName`. Réponses persistées dans `SharedPreferences` via `StorageService.saveOnboardingAnswers` (clé `prefOnboardingAnswers`, JSON encodé).

**Pourquoi** : Les 4 questions émotionnelles (frein, durée, impact, moment) permettent de qualifier l'état psychologique de l'utilisateur avant d'arriver sur le paywall — augmente la pertinence perçue et la conversion. Questions recentrées sur l'émotion plutôt que sur les objectifs génériques (ADR-021).

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

---

## ADR-020 — Remplacement des catégories Confiance, Amour et Pleine conscience par Émotions

**Décision** : Les catégories `confidence` (Confiance), `amour` (Amour) et `mindfulness` (Pleine conscience) sont supprimées. Elles sont remplacées par une seule catégorie `emotion` (Émotions, 💛) avec 5 séances correspondant aux fichiers audio réels dans `assets/audio/Emotion/`.

**Pourquoi** : Les dossiers audio de ces catégories étaient vides ou avec des chemins incorrects. L'utilisateur dispose de vrais fichiers audio dans `assets/audio/Emotion/` couvrant des thématiques émotionnelles (amour de soi, joie, anxiété, peur, amour). Regrouper sous "Émotions" est plus cohérent et évite des catégories sans contenu.

**Implémentation** : Dossier audio `Emotion/` (majuscule conservée pour correspondre au nom de dossier existant). Chemins audio alignés exactement sur les noms de fichiers réels.

---

## ADR-019 — Paywall natif RevenueCat (PaywallView)

> ⚠️ Remplacée par **ADR-025** (12/08/2026) — le paywall est redevenu un écran Flutter maison.

**Décision** : `PaywallPage` utilise `PaywallView` de `purchases_ui_flutter`. L'UI du paywall est entièrement gérée par RevenueCat depuis son dashboard — plus de code Flutter custom pour les offres, le pricing ou le design.

**Pourquoi** : Maintenir un paywall Flutter custom (texte hardcodé, prix fixe, logique d'achat) impliquait de recompiler et republier l'app à chaque changement d'offre ou de prix. `PaywallView` charge la configuration depuis le dashboard RevenueCat en temps réel, permet les A/B tests natifs, et gère automatiquement les états de chargement, les erreurs et la restauration des achats.

**Implémentation** : `PaywallPage` est un `ConsumerStatefulWidget`. Au `initState`, `Purchases.getOfferings()` est appelé pour charger l'Offering `default` avant d'afficher `PaywallView` — un `CircularProgressIndicator` est affiché pendant le chargement, un message d'erreur si l'Offering est absent. `PaywallView` est rendu dans un `Scaffold` avec `offering` passé explicitement. Les callbacks `onPurchaseCompleted` et `onRestoreCompleted` appellent `storageService.setIsPremium(true)` avant de rediriger vers `/home`. `onDismiss` ne se déclenche que sur action explicite de l'utilisateur. RevenueCat est initialisé dans `main()` via `AudioService.init()` avec `PurchasesConfiguration(revenueCatApiKey)` — la clé API est isolée dans `lib/core/config/revenue_cat_config.dart`.

**Alternative rejetée** : Garder le paywall custom Flutter — prix hardcodé, pas de A/B test possible, obligation de release pour chaque changement d'offre.

---

## ADR-021 — Questions onboarding émotionnelles pour améliorer la conversion paywall

**Décision** : Remplacement des 3 questions génériques (objectif, moment préféré, état) par 4 questions émotionnelles centrées sur le ressenti immédiat de l'utilisateur.

| # | Question | But |
|---|---|---|
| Q1 | Qu'est-ce qui t'empêche de te sentir bien en ce moment ? | Identifier le frein principal |
| Q2 | C'est quelque chose que tu ressens... ? | Qualifier la durée / ancrage du problème |
| Q3 | Qu'est-ce que ça affecte le plus ? | Identifier le domaine de vie impacté |
| Q4 | Tu aurais plutôt 5 minutes pour toi... ? | Trouver le bon moment pour proposer la méditation |

**Pourquoi** : Les questions génériques (objectif, moment, humeur) ne créaient pas de lien émotionnel avec l'utilisateur avant le paywall. Les nouvelles questions miroir le ressenti immédiat, ce qui augmente la pertinence perçue de l'abonnement et la conversion. Pattern "qualify before convert" utilisé par Calm, Headspace et Noom.

**Implémentation** : `_totalSlides` passe de 6 à 7. Clé q4 ajoutée dans `OnboardingState.answers`. `_isSlideProceedable` mis à jour pour bloquer sur q4 (page 5) avant la saisie du prénom (page 6).

---

## ADR-022 — Haptic feedback ciblé sur les actions clés

**Décision** : Vibrations légères iOS via `HapticFeedback` (Flutter `flutter/services.dart`, sans dépendance externe) sur un ensemble ciblé d'interactions utilisateur, et non sur tous les `onTap`.

**Mapping** :
- `mediumImpact` — `AppButton` (centralisé, couvre paywall / onboarding / profile / form save)
- `mediumImpact` — `SessionCard` (lance une lecture = validation)
- `lightImpact` — `CategoryListCard`, `FeaturedSessionCard`, seek ±15s du player
- `selectionClick` — sélection d'option dans `QuestionSlide` (onboarding)
- `heavyImpact` — bouton play/pause central du player (action forte qui démarre/arrête la méditation)
- `lightImpact` × 5 — `OnboardingLoadingPage`, à chaque apparition d'une nouvelle phrase pendant la barre de progression de 5s (synchronisé avec les seuils 0%, 20%, 40%, 60%, 80%)

**Pourquoi** : L'haptic feedback signale au système nerveux qu'une action a été enregistrée — c'est ce qui distingue une UX premium d'une UX "ok". Mais des vibrations sur tous les taps deviennent agaçantes. Cibler les actions à valeur (validation, navigation principale, contrôles audio) plutôt que les retours arrières ou les éléments décoratifs.

**Implémentation** : `import 'package:flutter/services.dart';` dans 6 fichiers. Le `HapticFeedback` est appelé synchronously avant la callback utilisateur — il ne bloque pas. Centralisation dans `AppButton` pour éviter la répétition. Pour la page de chargement, un `Set<int> _vibratedPhrases` garde l'idempotence (chaque seuil ne déclenche qu'une vibration unique).

**Test** : Les haptics ne fonctionnent pas dans le simulateur iOS — tester uniquement sur device physique.

---

## ADR-023 — Images de couverture par session (assets/images/sessions/)

**Décision** : Chaque `SessionModel` peut avoir un `imageFile` (String?) qui pointe vers une image de couverture dans `assets/images/sessions/<categorie>/<session_id>.png`. Le player affiche cette image (220×220, `ClipRRect` arrondi) à la place du placeholder turquoise + note de musique. Si le fichier est absent ou vide, `Image.asset` errorBuilder retombe sur `_CoverPlaceholder` (même visuel que l'ancien placeholder).

**Structure** :
```
assets/images/sessions/
├── decouverte/      (3 images : decouverte_1.png … decouverte_3.png)
├── actualite/       (5 images)
├── stress/          (5 images)
├── sleep/           (5 images)
├── breathing/       (4 images)
└── emotion/         (5 images)
```

**Pourquoi** : Le placeholder unique pour toutes les séances rend l'app générique. Une image dédiée par session augmente la perception de qualité éditoriale et aide à différencier visuellement les méditations dans le player et potentiellement dans les listes. Le fallback automatique permet de déployer le code avant d'avoir toutes les images finales — chaque image peut être ajoutée incrémentalement.

**Implémentation** : Champ `imageFile` optionnel ajouté à `SessionModel` (constructeur + `copyWith`, sans toucher à `==`/`hashCode`). Tous les chemins déclarés dans `ExploreRepository`. Dans `PlayerPage` : `session.imageFile != null ? Image.asset('assets/${session.imageFile}', errorBuilder: ...) : _CoverPlaceholder()`. Dossiers déclarés dans `pubspec.yaml > flutter > assets`.

---

## ADR-024 — Noms de fichiers audio en ASCII pur

**Décision** : Tous les fichiers audio dans `assets/audio/` utilisent uniquement de l'ASCII (pas d'accents, ni d'espaces). Ex. `4-le-voyageur-qui-sarrete.mp3` au lieu de `4-le-voyageur-qui-sarrête.mp3`.

**Pourquoi** : macOS stocke les noms de fichiers en **NFD** (forme décomposée Unicode : `é` = `e` + ` ́`), tandis que Flutter charge les assets en **NFC** (forme composée : `é` = un seul codepoint). Les fichiers avec accents étaient introuvables au runtime (`PlatformException` au `setAsset`) — c'est ce qui empêchait les leçons de Découverte de démarrer. Renommer en ASCII supprime la classe entière de bug.

**Application au-delà de l'audio** : Même logique appliquée à l'artwork Now Playing (`Logo 1.jpeg` chargé via `rootBundle.load` puis écrit dans un fichier temp et passé en `file://` URI à `MPNowPlayingInfoCenter`, car `asset:///` avec espace n'est pas supporté nativement par iOS).

**Implémentation** : 14 fichiers audio renommés via `mv`, chemins mis à jour dans `ExploreRepository`. `audio_handler.dart` `initSession` charge le logo en bytes et écrit dans `${Directory.systemTemp.path}/quieto_artwork.jpeg` à chaque session.

---

## ADR-018 — Pages de transition onboarding : loading + preview avant le paywall

**Décision** : Deux pages s'intercalent entre la dernière question de l'onboarding (saisie du prénom) et le paywall :
1. `OnboardingLoadingPage` (`/onboarding-loading`) — logo 80×80, `CircularProgressIndicator` déterministe animé de 0 à 100% en 5000ms (`CurvedAnimation`, `Curves.easeInOut`), vagues concentriques animées (`_WavePainter`, 3 ellipses avec décalages de phase), particules flottantes en arrière-plan (`_ParticlePainter`, 8 particules constantes, 8px diamètre, opacité max 0.45). Redirect automatique vers `/onboarding-preview` après 400ms.
2. `OnboardingPreviewPage` (`/onboarding-preview`) — Liste de toutes les catégories disponibles (depuis `exploreCategoriesProvider`) avec message personnalisé au prénom. Bouton CTA "Accéder à mes séances" → `context.go('/paywall')`.

**Pourquoi** : La transition directe onboarding → paywall est abrupte. La page de loading crée une attente intentionnelle (5s) qui suggère une personnalisation en cours (engagement psychologique). Les animations de vagues et particules renforcent l'atmosphère apaisante de l'app. La page preview montre à l'utilisateur les séances qui l'attendent, justifiant ainsi l'abonnement avant d'arriver sur le paywall.

**Implémentation** : `OnboardingLoadingPage` est un `ConsumerStatefulWidget` avec `TickerProviderStateMixin` (3 `AnimationController` : progression 5000ms, vagues 2000ms en boucle, particules 3000ms en boucle). `_WavePainter` et `_ParticlePainter` sont des `CustomPainter` — rendu bas niveau via `Canvas.drawOval` / `Canvas.drawCircle`. `OnboardingPreviewPage` est un `ConsumerWidget` — zéro état local. Le prénom est mis à jour dans `firstNameProvider` (StateProvider) immédiatement après la sauvegarde dans SharedPreferences, pour que les deux pages lisent le bon prénom sans re-lecture du stockage.

---

## ADR-025 — Retour au paywall Flutter maison (remplace ADR-019)

*Consignée le 12/08/2026 (Scribe) — décision prise durant l'été 2026, branche `feat/paywall-flutter`.*

**Décision** : Le paywall est de nouveau un écran Flutter maison (`lib/features/paywall/presentation/paywall_screen.dart`) ; le `PaywallView` natif de `purchases_ui_flutter` n'est plus utilisé. Les offres et prix réels restent chargés depuis RevenueCat (`purchases_flutter`).

**Pourquoi** : le chantier conversion exigeait un contrôle total de l'écran — d'après les commits : paywall jamais fermé en silence (`f16eb92`, release 1.0.12), prix réels RevenueCat + bypass dev coupé (`fa09657`), cache + préchargement des offres et croix isolée (`4aeef03`), et étiquette Vigie de la surface d'origine `?from=premium&src=…` (`7d9a5c5`, 1.0.15).

**Sources** : historique git de `feat/paywall-flutter`, `app/router.dart` (`AppRoutes.paywallDepuis`).

---

## ADR-026 — App verrouillée en mode portrait

*Consignée le 12/08/2026 (Scribe) — décision du 11/08/2026, commit `531dda1`.*

**Décision** : L'app ne bascule plus jamais en paysage — verrou posé côté Flutter, `ios/Runner/Info.plist` (`UIRequiresFullScreen`) et manifest Android. Le « mode paysage pour le player » de la roadmap SPECS est abandonné.

**À vérifier** : comportement réel en penchant le téléphone au prochain build (note du journal de bord).

---

## ADR-027 — Tarifs : stratégie « annuel d'abord »

*Consignée le 12/08/2026 (Scribe) — stratégie assumée par Paul (journal de bord, 11-12/08/2026).*

**Décision** : Essai gratuit 7 jours puis **89 €/an** ou **16,90 €/mois**. Le mensuel est volontairement cher pour ancrer le prix ; on ne remet pas le mensuel en avant.

**Pourquoi** : l'annuel est la base du revenu stable (le churn mensuel est rapide) ; objectif 30-40 k$/mois sur le marché français (~3 200 abonnés au mix 80/20 actuel).

---

## ADR-028 — Refonte visuelle : illustrations gouache (remplace l'esprit d'ADR-023)

*Consignée le 26/08/2026 (Scribe) — chantier des 25-26/08, commits `c8e3ba5`, `eb30399`, `37a9771`. Parti pris complet : `DIRECTION-ARTISTIQUE.md` (25/08), méthode : `PROMPTS-VISUELS.md`.*

**Décision** : Toutes les images de l'app passent en **gouache générée** (API Gemini) : les 35 covers de séances (WebP, liées au titre de chaque séance), 7 bandeaux de catégorie 1400×788 (`assets/images/categories/`), cartes de la home illustrées. La doctrine « dessin en code plutôt qu'images » ne vaut plus pour l'illustration statique — elle reste vraie pour l'animation (shaders GPU de la home).

**Pourquoi** : audit DA du 25/08 — les anciennes images (dégradés lisses, halos turquoise) criaient « généré par IA » ; et la home 100 % texte participait à la fuite home → 1ʳᵉ séance (12 %).

---

## ADR-029 — Plus aucun outil de dev dans l'app (remplace ADR-014)

*Consignée le 26/08/2026 (Scribe) — commits `f9ab2e9` (17/08) puis `9e82c22` (26/08, préparation 1.0.20).*

**Décision** : L'app ne contient **plus aucun chemin de dev** : ni forçage premium (`_devUnlockPremium`, puis `devForcerPremium`, puis la carte provisoire « Premium forcé (dev) » / flag `premium_force_dev`), ni boutons profil (animation programme, avancer d'un jour, refaire l'onboarding), ni flèches dev d'onboarding, ni mode `?demo=1` de la création de programme, ni `avancerJourDev()`. Un outil provisoire peut revenir le temps d'un chantier (double verrou `kReleaseMode`), mais il est **retiré avant tout bump de version**.

**Pourquoi** : chaque outil de dev est un risque de fuite en prod et du code mort à maintenir ; le double verrou ne remplace pas l'absence.

---

## ADR-030 — Suppression de la proposition de rappel en fin de première séance

*Consignée le 26/08/2026 (Scribe) — demande de Paul, commit `099b1df` (part avec la 1.0.20).*

**Décision** : Le bottom sheet « À quelle heure veux-tu prendre soin de toi demain ? » n'apparaît plus après une séance. Retirés avec lui : le flag `notification_prompt_shown` et les événements Vigie `rappel_propose` / `rappel_permission`. Le réglage « Heure du rappel » du profil reste. La demande de notification devra vivre **en fin d'onboarding** (chantier n°1 d'`AMELIORATIONS.md`).

**Pourquoi** : mesuré dans la Vigie — 258 propositions pour 4 000 arrivées : les 88 % qui n'écoutent jamais de séance ne voyaient JAMAIS la proposition. Le mauvais moment, pas le mauvais outil.

---

## ADR-031 — URLs légales sur cofonde.com (plus de dépendance Notion)

*Consignée le 26/08/2026 (Scribe) — commit `6985199` (part avec la 1.0.20).*

**Décision** : Les liens confidentialité et CGU du paywall (`paywall_page.dart`) et du profil (`profile_page.dart`) pointent sur `https://cofonde.com/quieto-confidentialite` et `https://cofonde.com/quieto-cgu` (site statique Netlify de la SASU).

**Pourquoi** : dépendre du partage web Notion pour un lien obligatoire dans l'app était un risque de rejet Apple. ⚠️ Ne pas supprimer les pages Notion tant que la 1.0.20 n'est pas en ligne : les versions en prod pointent encore dessus.

---

## ADR-032 — Jour 1 du tout premier programme : toujours « Ma première méditation »

*Consignée le 26/08/2026 (Scribe) — décision Paul, app `258ee18` + backend `39853fd` (déployé le 26/08). Actif à partir de la 1.0.20.*

**Décision** : Tant que la personne n'a **jamais terminé de séance** (`parcoursDejaCree` faux OU `completedCount == 0`), `genererParcours` reçoit `premierParcours: true` et le serveur force « Ma première méditation » en jour 1 (verrou déterministe `forcerPremiereMeditation`, le mot de Louane suit sa séance). Inerte pour les versions ≤ 1.0.19 (flag absent).

**Pourquoi** : quasi personne n'a jamais médité — le programme doit commencer par la porte d'entrée, pas par une séance quelconque.

---

## ADR-033 — Paywall à chaque démarrage à froid pour les non-abonnés

*Consignée le 28/08/2026 (Scribe) — décision Paul, app `5acdfff` + animation `29f2b65` (partent avec la 1.0.20).*

**Décision** : Au démarrage à FROID, si l'onboarding est fini et que `subscriptionProvider` est false (l'entitlement RC couvre premium ET essai), le splash envoie sur la home puis pousse `/paywall?src=ouverture` après 500 ms : la home s'installe, le mur monte du bas en 900 ms (variante `lente: true` de `sheetPage`, easeInOutCubic, feuille opaque) sous un voile noir à 0,6. Réservé à `src=ouverture` ; croix habituelle à 3 s ; le retour du background ne repasse pas par le splash → rien. L'écran du mur lui-même est **inchangé** (règle « le mur ne se touche pas », ADR implicite du 25/08).

**Pourquoi** : conseil Superwall/RevenueCat « paywall on every app open » — lift attendu +10-30 % de démarrages d'essai (pas de chiffre isolé publié). App tuée → mur ; aller-retour WhatsApp → rien : exactement le comportement voulu par Paul. La source Vigie `ouverture` mesurera ce que ça rapporte.

---

## ADR-034 — Bas de l'app en pilules flottantes ; mini-lecteur supprimé

*Consignée le 28/08/2026 (Scribe) — journée du 28/08 avec Paul, commits `83f21a3` → `2626056` → `dee58a0` (partent avec la 1.0.20).*

**Décision** : La nav et la saisie Louane sont deux **pilules flottantes** en voile bleu nuit translucide sur flou (nav : `AppColors.background` à 75 % ; saisie : `#122036` à 85 %, teinte exacte fournie par Paul), sans bordure ni couronne. Le contenu défile DERRIÈRE elles partout (Stack + `SafeArea bottom:false` + marges basses `MediaQuery.padding`) — seuls les ovales flottent, plus de « mur » opaque. Sur Louane, la nav se range en défilant vers le bas et revient vers le haut (en plus du clavier). Espacements calés par Paul : 14 px entre les pilules, saisie seule à 26 px du bord, 6 px au-dessus du clavier (`AnimatedPadding` 300 ms ; clavier détecté via `View.of`, le Scaffold consomme les viewInsets). Le **MiniPlayer est supprimé de l'interface** : pilotage par écran verrouillé + centre de contrôle. Compromis assumé : plus de raccourci in-app pour rouvrir l'écran de séance (repasser par la carte). `mini_player.dart` reste dans le code, orphelin.

**Pourquoi** : demande de Paul — un bas d'écran aéré façon Headspace/iOS 26 ; le mini-lecteur cassait l'effet flottant.

---

## ADR-035 — Interrupteur « Premium (mode test) » en kDebugMode (précise ADR-029)

*Consignée le 28/08/2026 (Scribe) — commit `d7e232b`.*

**Décision** : Le profil porte un interrupteur « 🛠 Premium (mode test) » visible UNIQUEMENT en `kDebugMode` (donc jamais en TestFlight ni App Store) ; `debugForcerPremium` fait ensuite ignorer RevenueCat pour la session. Ce n'est pas une entorse à ADR-029 : `kDebugMode` est un verrou de **compilation**, l'outil n'existe pas dans un build boutique — contrairement aux anciens flags runtime à double verrou. ⚠️ Le backend fait confiance au flag `abonne` envoyé par l'app (`index.js:1165`) : en debug forcé, Louane se comporte aussi en Premium.

**Pourquoi** : tester tout le parcours Premium sur iPhone réel sans payer, sans réintroduire le risque de fuite en prod.

---

## ADR-036 — Jamais de séance flash « Une minute pour toi » dans un programme 7 jours

*Consignée le 30/08/2026 (Scribe) — décision Paul du 30/08, backend `5b5dcee` (déployé le 30/08, `genererParcours`), app `00e313b` (part avec la 1.0.21).*

**Décision** : Les séances de la catégorie **express** (1 à 3 min) ne composent **jamais** un jour de programme 7 jours. Backend : le catalogue montré au modèle est filtré (`SEANCES_PARCOURS`, 27 séances sur 35), règle explicite dans `PROMPT_PARCOURS`, et **verrou dans `validerParcours`** — un id express est traité comme invalide et remplacé, tous les filets piochent dans la liste filtrée ; `IDS_GRATUITS` filtré (jour 1 gratuit = les 3 découverte) ; programme par défaut « sommeil » : jour 1 `express_4` → `decouverte_1` avec mot ajusté. App : le programme d'aperçu de l'onboarding (`weekly_program.dart`) remplace « Juste avant de dormir » (3 min, express) par « Plongée dans le silence » (6 min) dans la branche « moins de 5 minutes » du pool « Mieux dormir ». Elles restent bien sûr dans le catalogue et jouables à l'unité. **ADR-032 confirmée au passage** : « Ma première méditation » reste toujours le jour 1 du tout premier programme.

**Pourquoi** : trop courtes pour porter un jour de programme — un « jour 3 » d'une minute dévalorise le parcours. Effet attendu côté Vigie : chute VOULUE des `express_*` dans les programmes.

---

> ℹ️ *Note du Scribe (28/09/2026)* : aucune décision n'a été consignée ici entre le 30/08 et le 26/09/2026. Celles de cette période (audit sécurité en deux temps, mise en page iPad zoomée, mode vocal annulé, paiement B2B par Stripe…) sont dans le journal, `../docs/JOURNAL-QUIETO.md`.

---

## ADR-037 — Un seul dépôt pour tout Quieto

*Consignée le 28/09/2026 (Scribe) — fait le 26/09/2026, commits `63aba81` → `4ad9f96` → `bdf45a6` → `7ee3aeb`.*

**Décision** : Tout Quieto vit dans **un dépôt**, `~/Desktop/dev/Quieto` → `github.com/Paul-Oll/Quieto` (privé), branche `main`. `app/` = l'ancien `QuietoApp` (branche `feat/vigie-conversion`) et `backend/` = l'ancien `quieto-backend`, importés **avec leur historique** (git subtree) ; `sites/entreprise/`, `sites/cofonde/`, `docs/` (dont le journal) et `logo/` copiés. « Quieto IA » (compta, archives, la Vigie) reste **volontairement dehors**. Les anciens dossiers `QuietoApp` et `quieto-backend` sont des archives : on n'y travaille plus. Le push se fait depuis GitHub Desktop, par Paul. Les fichiers de secrets et de configuration Firebase restent hors git et se recopient à la main (liste dans `CONFIG.md`).

**Pourquoi** : un seul endroit à ouvrir, à sauvegarder et à relire ; app, backend, sites et journal avancent ensemble dans le même historique.

---

## ADR-038 — Le modèle se règle en un seul endroit ; GPT-6 Luna essayé, retour à GPT-5.6 Luna

*Consignée le 28/09/2026 (Scribe) — backend `380a08a` (26/09), décision de Paul du 28/09, backend `da1fbef`.*

**Décision** : Le modèle de TOUS les appels (Voix, Mémoire, Veilleur, Boussole, Juge, `genererParcours`, `accueilOnboarding`) est dans **une constante, `MODELE`**, en tête de `backend/functions/index.js`. Changer de modèle = changer cette ligne, **puis rejouer le banc de voix** (`backend/banc/banc-voix.mjs`) avant de déployer. **GPT-6 Luna** a tourné en prod du 26 au 28/09/2026 : moitié prix (Voix ~0,037 ¢ par message contre ~0,062 ¢), réponses plus courtes (116 caractères contre 126 sur le banc de 61 réponses), 4 questions à choix au lieu de 13. **Paul a choisi de revenir à GPT-5.6 Luna** le 28/09.

**Pourquoi** : « qu'elle parle normalement, comme avant » (Paul, 28/09) — il préfère la voix de la 5.6 ; GPT-6 avait la moitié du prix mais pas le même ton. Les caractères parasites qu'il avait vus ne venaient pas de GPT-6 : les deux modèles en produisent (ADR-039).

---

## ADR-039 — Filet serveur : jamais un caractère d'une autre écriture dans ce que dit Louane

*Consignée le 28/09/2026 (Scribe) — retour de Paul du 28/09 (capture : « Désolée◌ੑ »), backend `7cb12eb`.*

**Décision** : Le serveur passe tout ce que Louane écrit dans `sansEcritureEtrangere` : forme NFC d'abord (pour qu'un « é » décomposé ne soit pas pris pour un parasite), puis on ne garde que **l'écriture latine et les signes communs** (chiffres, ponctuation, espaces). S'applique à la Voix (`bullesDepuisTexte`), à l'accueil de l'onboarding et au programme (`validerParcours`). Un signal Vigie `ecritureEtrangere` compte les bulles touchées, sans jamais stocker de texte.

**Pourquoi** : Luna lâche parfois un jeton d'une autre écriture en fin de bulle — goujarati au rejeu du 28/09, cyrillique au banc du 26/09, tous deux sur la 5.6. Changer de modèle ne règle donc rien ; un filet déterministe, si. Dans la même veine que `sansTiretLong`, `sansEmoji` et `sansPrenomFinal`.

---

## ADR-040 — Quand Luna copie un exemple, on corrige l'exemple

*Consignée le 28/09/2026 (Scribe) — retour de Paul du 28/09, backend `7cb12eb`.*

**Décision** : Si la personne répond juste « salut » à la question d'ouverture de Louane, Louane **rend le salut et repose LA MÊME question, plus légère** : jamais une autre question sortie de nulle part, jamais une formule creuse (« je te laisse reprendre le fil »). Trois endroits corrigés ensemble dans `index.js` : la règle du registre, **l'exemple** de `PROMPT_VOIX` et `consigneAccueil`. Rejeu 3/3 conforme sur la 5.6 et sur la 6.

**Pourquoi** : la mauvaise réponse (« t'as pu souffler un peu ? ») était recopiée de l'exemple du prompt. Leçon : corriger l'exemple, pas seulement la règle.

---

## ADR-041 — Voile flou de l'en-tête Louane : 6 couches, pas 14

*Consignée le 28/09/2026 (Scribe) — retour de Paul du 28/09 (page saccadée), app `7cb12eb`, part avec la 1.0.28.*

**Décision** : Le voile de l'en-tête de la page Louane (`_VoileEnTete`, `louane_page.dart`) passe de **14 à 6 couches de `BackdropFilter`** (`_sigmas = [1.5, 2.5, 4.0, 6.0, 9.0, 20.0]`), plus espacées, pour le même flou cumulé au sommet (≈ 24). Précise le flou progressif introduit entre la 1.0.23 et la 1.0.26.

**Pourquoi** : chaque couche fait relire et flouter le haut de l'écran par le GPU à chaque image ; à 14 couches la page saccadait en permanence, alors que les autres pages restaient fluides. Testé par Paul sur son iPhone 11 en build release le 28/09 : « beaucoup mieux ».
