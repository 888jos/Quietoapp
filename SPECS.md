# Specs produit — Quieto

## Concept

Quieto est une application de méditation guidée **en français**, pensée pour rendre la méditation accessible à tous les niveaux. Contenu statique (audio embarqué) pour le MVP, sans backend.

## Fonctionnalités MVP

### Onboarding
- 7 slides : 2 introductions + 4 questions émotionnelles à choix unique + saisie du prénom
- Pas de bouton "Passer" — l'utilisateur doit compléter tout le flow
- "Commencer" sur la dernière slide → sauvegarde réponses + prénom + marque l'onboarding comme terminé → **Loading** → **Ready** → **Paywall** (puis Home)
- Réponses persistées dans SharedPreferences (`prefOnboardingAnswers`)
- **Page Loading** (`/onboarding-loading`) : logo (80×80) centré + cercle de progression 0→100% en 5000ms + animations vagues et particules + 5 phrases qui apparaissent progressivement (fade in) → redirect automatique vers `/onboarding-ready` après 300ms
- **Page Ready** (`/onboarding-ready`) : logo (80×80) + "C'est prêt ✨" + "Ton essai gratuit de 7 jours est prêt" + CTA "Découvrir Quieto" → `/paywall`. Fade in 600ms à l'entrée. Pas de retour arrière possible.

### Home ✅
- Header : logo à gauche + greeting RichText à droite (fade in 600ms) — "Salut [prénom]," en `textMuted` + "on fait quoi aujourd'hui ?" en `textPrimary` bold
- Carte "Priorité du moment" mise en avant (Découverte 🧘, 3 séances, bordure accent) → `/category/decouverte`
- Liste verticale de toutes les catégories (emoji, nom, description, nb séances) → `/category/:id`

### Explorer
- Grille 2 colonnes de toutes les catégories
- Recherche textuelle en temps réel (filtre par nom/description)

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
- Section "Paramètres" : toggle notifications (persisté SharedPreferences) + reset onboarding (→ `/onboarding`)
- Section "Informations légales" : politique de confidentialité + conditions d'utilisation (ouvre URL via `url_launcher`)

### Paywall
- Affiché via `PaywallView` de `purchases_ui_flutter` — UI générée nativement par RevenueCat depuis le dashboard
- `onDismiss` → `context.go('/home')`
- `onPurchaseCompleted` → `context.go('/home')`
- `onRestoreCompleted` → `context.go('/home')`
- Accessible via `context.go` depuis l'onboarding (pas de retour) ou `context.push` depuis le profil (retour possible)

## Catégories de contenu (MVP)

| Catégorie | Emoji | Premium | Séances |
|---|---|---|---|
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

## Monétisation

- Modèle freemium : 1 catégorie gratuite (🧘 Découverte), toutes les autres requièrent un abonnement
- Badge "New !" sur la catégorie Actualité : `FeaturedSessionCard` (home priorité) + `CategoryListCard` (liste verticale)
- Abonnement mensuel : 4,99 € / mois
- Intégration RevenueCat (`purchases_flutter`)
- Entitlement : `premium`
- Offering : `default`

## Assets audio

Les fichiers audio sont organisés par catégorie dans `assets/audio/` :

```
assets/audio/
├── decouverte/
├── actualite/
├── stress/
├── sleep/
├── breathing/
└── Emotion/
```

Convention de nommage : `<dossier>/<index>-<slug>.mp3` en **ASCII pur** (pas d'accents, pas d'espaces) — ex. `stress/4-le-voyageur-qui-sarrete.mp3`. macOS stockerait les accents en NFD alors que Flutter charge en NFC, créant des fichiers introuvables au runtime (voir ADR-024).

## Assets images de couverture

Les images de couverture des séances sont dans `assets/images/sessions/` :

```
assets/images/sessions/
├── decouverte/   (decouverte_1.png … decouverte_3.png)
├── actualite/    (actualite_1.png … actualite_5.png)
├── stress/       (stress_1.png … stress_5.png)
├── sleep/        (sleep_1.png … sleep_5.png)
├── breathing/    (breathing_1.png … breathing_4.png)
└── emotion/      (emotion_1.png … emotion_5.png)
```

Convention : `sessions/<categorie>/<session_id>.png`. Le player affiche cette image dans le cover 220×220, avec fallback automatique sur le placeholder note de musique si l'image est absente ou corrompue.

## UX haptic feedback

Vibrations iOS subtiles via `HapticFeedback` natif (zéro dépendance) sur les actions clés :
- **medium** : tous les `AppButton`, tap sur `SessionCard` (lance une lecture)
- **light** : tap sur les cartes catégorie (`CategoryListCard`, `FeaturedSessionCard`), seek ±15s
- **selection** : choix d'une option dans une question de l'onboarding
- **heavy** : bouton play/pause central du player
- **light × 5** : pendant la barre de chargement de l'onboarding (1 vibration par phrase, à 0% / 20% / 40% / 60% / 80%)

Voir ADR-022 pour la stratégie complète. Test obligatoire sur iPhone physique (les haptics ne fonctionnent pas dans le simulateur).

## Roadmap post-MVP

- [ ] Intégration Firebase (auth, analytics)
- [ ] Téléchargement hors-ligne
- [ ] Notifications de rappel de méditation
- [ ] Statistiques avancées (streak, graphe hebdomadaire)
- [x] CategoryDetailPage complète
- [ ] Favoris
- [ ] Mode paysage pour le player
