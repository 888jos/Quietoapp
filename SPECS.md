# Specs produit — Quieto

> Maj 12/08/2026 — resynchronisé avec le code (v1.0.15+22). Ce document datait du MVP ; les sections marquées « historique » décrivent l'app d'avant. Pour l'état produit courant, `QUIETO.md` fait foi.
> Maj 26/08/2026 — resynchronisé avec la v1.0.20+29 (notes datées dans les sections concernées).

## Concept

Quieto est une application de méditation guidée **en français**, pensée pour rendre la méditation accessible à tous les niveaux. Les séances audio sont hébergées sur **Firebase Storage** et lues en **streaming** (connexion requise — le seul audio embarqué est `assets/audio/onboarding_ambient.mp3`). Backend : Cloud Functions (`~/dev/quieto-backend` — `louane`, `trace`, `genererParcours`, `revenuecat`).

## Fonctionnalités MVP

### Onboarding (⚠️ historique — V1)

> Depuis la V2 « orientée conversion » (commit `4317a1d`, puis 1.0.13+), le flow réel est (maj 26/08/2026, vérifié dans le code) :
> connexion Apple/Google (jamais bloquante) → questions → **compréhension** (Louane résume ce qu'elle a compris, bulles servies par la Cloud Function `accueilOnboarding` — remplace loading/ready depuis la 1.0.17, qui restent en repli) → **respiration (breath)** → Apple Santé (iOS uniquement) → confiance (trust) → paywall → home.
> Source : `lib/features/onboarding/` et `app/router.dart`. Le descriptif V1 ci-dessous est conservé pour mémoire.
- 7 slides : 2 introductions + 4 questions émotionnelles à choix unique + saisie du prénom
- Pas de bouton "Passer" — l'utilisateur doit compléter tout le flow
- "Commencer" sur la dernière slide → sauvegarde réponses + prénom + marque l'onboarding comme terminé → **Loading** → **Ready** → **Paywall** (puis Home)
- Réponses persistées dans SharedPreferences (`prefOnboardingAnswers`)
- **Page Loading** (`/onboarding-loading`) : logo (80×80) centré + cercle de progression 0→100% en 5000ms + animations vagues et particules + 5 phrases qui apparaissent progressivement (fade in) → redirect automatique vers `/onboarding-ready` après 300ms
- **Page Ready** (`/onboarding-ready`) : logo (80×80) + "C'est prêt ✨" + "Ton essai gratuit de 7 jours est prêt" + CTA "Découvrir Quieto" → `/paywall`. Fade in 600ms à l'entrée. Pas de retour arrière possible.

### Home ✅
- Header : logo à gauche + greeting RichText à droite (fade in 600ms) — "Salut [prénom]," en `textMuted` + "on fait quoi aujourd'hui ?" en `textPrimary` bold
- Carte "Priorité du moment" mise en avant → `/category/decouverte`
- Liste verticale de toutes les catégories (nom, description, nb séances) → `/category/:id`
- *(maj 26/08/2026)* Ciel de nuit animé en **shaders GPU** : aurore boréale (`shaders/aurora.frag`) + voile laiteux et étoiles qui scintillent (`shaders/stardust.frag`), widgets `night_sky_header` / `glowing_moon`. Cartes **illustrées** (vignettes gouache, carte « Priorité du moment » façon Headspace). Carte du programme 7 jours (`parcours_card`) avec badge « Jour X sur 7 » + barre en 7 segments — le badge ne vit QUE sur cette carte, plus sur la page programme (`f715c6b`).

### Explorer (⚠️ supprimée — maj 12/08/2026)
L'onglet Explorer n'existe plus : la bottom nav est **Accueil / Louane / Profil**. Le catalogue s'atteint depuis l'accueil (cartes catégories → `/category/:id`). `lib/features/explore/data/explore_repository.dart` reste la source de vérité du catalogue (35 séances, 7 catégories).

### Louane & Programme 7 jours (ajout — maj 12/08/2026)
- **Louane** : compagnonne IA au centre de la nav (`/louane`) — chat avec l'utilisateur, recommandation de séances (cartes séance dans la conversation), rituel sommeil. Personnage dessiné en code (pas une image). Côté serveur : Cloud Function `louane`.
- **Programme 7 jours** (« parcours ») : créé par Louane via la Cloud Function `genererParcours` — écran de génération (`/parcours/creation`), constellation d'étoiles de progression, carte de partage (stories). Persisté en SharedPreferences (`ParcoursModel`).
- *(maj 26/08/2026, 1.0.20)* Le **jour 1 du tout premier programme est toujours « Ma première méditation »** : tant qu'aucune séance n'a jamais été terminée (`parcoursDejaCree` faux OU `completedCount == 0`), l'app envoie `premierParcours: true` et le serveur applique le verrou `forcerPremiereMeditation` (app `258ee18`, backend `39853fd`).
- Louane reste accessible aux utilisateurs **gratuits** (meilleure surface de conversion — voulu).

### Preparation screen
- Affiché avant chaque séance (tap sur une session card → `/preparation/:sessionId`)
- Affiche le titre de la séance + icône lotus + messages d'installation
- Barre de progression qui se remplit sur 5 secondes
- Tap n'importe où → fade out 300ms → `/player/:sessionId`
- Après 5 secondes → même fade out 300ms → `/player/:sessionId`

### Player
- Lecture audio via `just_audio`
- Contrôles : play/pause, +15s, -15s
- Barre de progression seekable
- Chaque séance repart toujours du début (pas de sauvegarde de position)
- Marquage automatique "complété" en fin de séance
- Image de couverture 220×220 par session (depuis `SessionModel.imageFile`, dans `assets/images/sessions/<categorie>/`) — fallback sur placeholder turquoise + note de musique si absente
- Mini player persistant affiché au-dessus de la bottom nav pendant la lecture/pause
  - Tap → ouvre la page player complète (`context.push`)
  - Bouton play/pause inline
  - Bouton stop : arrête la lecture et masque le mini player
- Métadonnées Now Playing (lock screen / notification) : titre, artist `Quieto`, durée réelle, artwork = `Logo 1.jpeg` (chargé via `rootBundle` → fichier temp → `file://` URI)

### Profil ✅
- Header : "👤 [prénom]" (fontSize 28, bold) + bouton "Modifier" pour éditer le prénom via bottom sheet
- Statistiques : minutes totales méditées, nombre de séances complétées
- CTA vers Paywall
- Section "Paramètres" : toggle notifications + « Heure du rappel » (bottom sheet, persisté SharedPreferences). *(maj 26/08/2026 : le « reset onboarding » était un outil de dev — retiré avec tous les autres, commit `9e82c22`.)*
- Section "Informations légales" : politique de confidentialité + conditions d'utilisation (ouvre URL via `url_launcher`) — *(maj 26/08/2026)* les URLs pointent sur **cofonde.com** (`/quieto-confidentialite`, `/quieto-cgu`) depuis la 1.0.20 (`6985199`), plus sur Notion.

### Paywall (maj 12/08/2026)
- **Paywall Flutter maison** (`lib/features/paywall/presentation/paywall_screen.dart`, branche `feat/paywall-flutter`) — le `PaywallView` natif RevenueCat n'est plus utilisé ; les offres et prix réels viennent de RevenueCat (`purchases_flutter`).
- Accessible via `context.go` depuis l'onboarding (pas de retour) ou en montée glissée depuis une séance premium / le profil (`/paywall?from=premium&src=…` — la Vigie note la surface d'origine pour savoir ce qui convertit).
- *(maj 26/08/2026)* La croix de fermeture est **en haut à gauche**, collée à la zone sûre (`37a9771`).

## Catégories de contenu

> Maj 12/08/2026 : le catalogue compte **7 catégories / 35 séances** — la catégorie **« Une minute pour toi » (⚡ express, 8 séances)** s'est ajoutée aux 6 ci-dessous. Source de vérité : `lib/features/explore/data/explore_repository.dart`.

| Catégorie | Emoji | Premium | Séances |
|---|---|---|---|
| Une minute pour toi (express) | ⚡ | Oui (les Express « de base » sont gratuits) | 8 séances express |
| Découverte de la méditation | 🧘 | Non (gratuit) | Ma première méditation (5min), Observer sans juger (6min), Le moment présent (8min) |
| Actualité & Surcharge mentale | 📰 | Oui (isNew: true) | Quand le monde brûle (8min), La guerre en bruit de fond (12min), Débrancher quand tout crie (5min), Recul sur l'actualité (7min), Pause info (10min) |
| Stress & Anxiété | 😤 | Oui | Quand le stress prend le dessus (5min), Respiration 4-7-8 (15min), Relâche (8min), Ancrage (3min), Le voyageur qui s'arrête (10min) |
| Sommeil | 🌙 | Oui | Détente du soir (10min), Visualisation apaisante (20min), Rituel pré-sommeil (7min), Entre deux mondes (5min), Plongée dans le silence (12min) |
| Respiration | 🌬️ | Oui | Cohérence cardiaque (5min), Respiration alternée (7min), Souffle apaisant (3min), Expansion thoracique (8min) |
| Émotions | 💛 | Oui | Apprendre à s'aimer (8min), Joie et énergie (7min), De l'anxiété au sourire (10min), Peur et courage (9min), L'amour (12min) |

## Design system

### Couleurs
| Token | Hex | Usage |
|---|---|---|
| `background` | `#0A1628` | Fond principal — bleu nuit |
| `cardSurface` | `#0D2137` | Surface des cartes |
| `accent` | `#5CE0D8` | Accent principal, CTA — turquoise |
| `accentDim` | `#265CE0D8` | Éléments subtils (15% opacité) |
| `textPrimary` | `#FFFFFF` | Texte principal |
| `textMuted` | `#99FFFFFF` | Texte secondaire (60% opacité) |

### Thème
- Dark only — pas de mode clair
- Material 3
- Pas de couleurs hardcodées en dehors de `AppColors`

## Monétisation (maj 12/08/2026)

- Modèle freemium : gratuit = catégorie 🧘 Découverte + les Express « de base » + Louane (non bridée, voulu) ; tout le reste requiert l'abonnement
- **Essai gratuit 7 jours**, puis **89 €/an** ou **16,90 €/mois** — stratégie « annuel d'abord » (le mensuel est volontairement cher pour ancrer le prix)
- Intégration RevenueCat (`purchases_flutter`)
- Entitlement : `premium`
- Offering : `default`

## Assets audio (maj 12/08/2026)

Les séances ne sont **plus embarquées** dans l'app : elles sont hébergées sur **Firebase Storage** et lues en streaming (`AudioPlayer.setUrl`, voir `lib/features/player/data/audio_handler.dart`). Le dossier `assets/audio/` ne contient plus que `onboarding_ambient.mp3` (musique d'ambiance).

Convention de nommage (toujours valable, côté Storage comme côté `audioFile`) : `<dossier>/<index>-<slug>.mp3` en **ASCII pur** (pas d'accents, pas d'espaces) — ex. `stress/4-le-voyageur-qui-sarrete.mp3`. macOS stockerait les accents en NFD alors que Flutter charge en NFC, créant des fichiers introuvables au runtime (voir ADR-024).

## Assets images (maj 26/08/2026 — refonte gouache complète)

**Covers de séances** (`assets/images/sessions/`) — les 35 séances ont chacune une illustration gouache liée à leur titre (chantier des 25-26/08, commits `c8e3ba5`, `eb30399`, `37a9771` ; méthode : `PROMPTS-VISUELS.md`) :

```
assets/images/sessions/
├── decouverte/   (decouverte_1.png … decouverte_3.png)
├── express/      (express_1.webp … express_8.webp)
├── actualite/    (actualite_1.webp … actualite_5.webp)
├── stress/       (stress_1.webp … stress_5.webp)
├── sleep/        (sleep_1.webp … sleep_5.webp)
├── breathing/    (breathing_1.webp … breathing_4.webp)
└── emotion/      (emotion_1.webp … emotion_5.webp)
```

Convention : `sessions/<categorie>/<session_id>.webp` (les 3 Découverte sont restées en `.png`). Le player affiche cette image dans le cover 220×220, avec fallback automatique sur le placeholder note de musique si l'image est absente ou corrompue.

**Bandeaux de catégorie** (`assets/images/categories/`, ajoutés le 26/08) — 7 paysages gouache 1400×788 (`actualite`, `breathing`, `decouverte`, `emotion`, `express`, `sleep`, `stress`.webp), un `coverImage` dédié par catégorie pour le header de `category_detail_page.dart` (dégradé du bas démarré à 0.82 pour ne pas éteindre l'illustration).

## UX haptic feedback

Vibrations iOS subtiles via `HapticFeedback` natif (zéro dépendance) sur les actions clés :
- **medium** : tous les `AppButton`, tap sur `SessionCard` (lance une lecture)
- **light** : tap sur les cartes catégorie (`CategoryListCard`, `FeaturedSessionCard`), seek ±15s
- **selection** : choix d'une option dans une question de l'onboarding
- **heavy** : bouton play/pause central du player
- **light × 5** : pendant la barre de chargement de l'onboarding (1 vibration par phrase, à 0% / 20% / 40% / 60% / 80%)

Voir ADR-022 pour la stratégie complète. Test obligatoire sur iPhone physique (les haptics ne fonctionnent pas dans le simulateur).

## Roadmap post-MVP (maj 12/08/2026)

- [x] Intégration Firebase (Auth Apple/Google/anonyme, Cloud Functions, Storage, App Check + analytics maison « la Vigie »)
- [ ] Téléchargement hors-ligne
- [x] Notifications de rappel de méditation (rappel quotidien doux, réglable dans le profil — `lib/core/services/notification_service.dart`). ⚠️ maj 26/08/2026 : la **proposition** de rappel en fin de 1ʳᵉ séance a été supprimée (`099b1df`) — plus aucun écran ne propose la notification dans le parcours ; le chantier « la demander en fin d'onboarding » est dans `AMELIORATIONS.md`
- [ ] Statistiques avancées (streak, graphe hebdomadaire)
- [x] CategoryDetailPage complète
- [ ] Favoris
- ~~Mode paysage pour le player~~ (abandonné : app verrouillée en portrait le 11/08/2026, commit `531dda1`)
