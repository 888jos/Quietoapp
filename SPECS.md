# Specs produit — Quieto

## Concept

Quieto est une application de méditation guidée **en français**, pensée pour rendre la méditation accessible à tous les niveaux. Contenu statique (audio embarqué) pour le MVP, sans backend.

## Fonctionnalités MVP

### Onboarding
- 6 slides : 2 introductions + 3 questions à choix unique (objectif, moment, état) + saisie du prénom
- Pas de bouton "Passer" — l'utilisateur doit compléter tout le flow
- "Commencer" sur la dernière slide → sauvegarde réponses + prénom + marque l'onboarding comme terminé → Home
- Réponses persistées dans SharedPreferences (`prefOnboardingAnswers`)

### Home ✅
- Header : logo "Quieto" + salutation personnalisée "Bonjour, [prénom]" (via StorageService)
- Scroll horizontal de bulles de catégories ("Programmes disponibles") → `/category/:id`
  - Actualité en 1ère position, Découverte exclue (mise en avant via FeaturedSessionCard)
- Carte "Priorité du moment" mise en avant (Découverte 🧘, 3 séances, bordure accent) → `/category/decouverte`
- Liste verticale de toutes les catégories (emoji, nom, description, nb séances) → `/category/:id`

### Explorer
- Grille 2 colonnes de toutes les catégories
- Recherche textuelle en temps réel (filtre par nom/description)

### Player
- Lecture audio via `just_audio`
- Contrôles : play/pause, +15s, -15s
- Barre de progression seekable
- Sauvegarde de position automatique (reprendre où on s'est arrêté)
- Marquage automatique "complété" en fin de séance

### Profil
- Statistiques : minutes totales méditées, nombre de séances complétées
- CTA vers Paywall

### Paywall
- Présentation des avantages Premium
- Bouton d'achat (intégration RevenueCat à finaliser)
- Restauration des achats

## Catégories de contenu (MVP)

| Catégorie | Emoji | Premium | Séances |
|---|---|---|---|
| Découverte | 🧘 | Non (gratuit) | Ma première méditation (5min), Observer sans juger (6min), Le moment présent (8min) |
| Stress | 😤 | Oui | Respiration 4-7-8 (5min), Body scan (15min) |
| Sommeil | 🌙 | Oui | Détente du soir (10min), Visualisation (20min) |
| Focus | 🎯 | Oui | Pleine conscience (5min), Méditation pomodoro (10min) |
| Anxiété | 💭 | Oui | Technique 5-4-3-2-1 (8min), Méditation de l'arbre (12min) |
| Respiration | 🌬️ | Oui | Cohérence cardiaque (5min), Respiration boîte (10min) |
| Confiance | 💪 | Oui | Affirmations positives (7min), Visualisation du succès (12min) |
| Pleine conscience | 🧘 | Oui | Scan des sensations (10min), Méditation du miroir (15min) |
| Actualité | 🌍 | Oui (isNew: true) | Détox numérique (8min), Ancrage face à l'incertitude (12min) |

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
- Badge "New !" sur la catégorie Actualité : `FeaturedSessionCard` (home priorité) + `CategoryBubble` (scroll horizontal) + `CategoryListCard` (liste verticale)
- Abonnement mensuel : 4,99 € / mois
- Intégration RevenueCat (`purchases_flutter`)
- Entitlement : `premium`
- Offering : `default`

## Roadmap post-MVP

- [ ] Intégration Firebase (auth, analytics)
- [ ] Téléchargement hors-ligne
- [ ] Notifications de rappel de méditation
- [ ] Statistiques avancées (streak, graphe hebdomadaire)
- [x] CategoryDetailPage complète
- [ ] Favoris
- [ ] Mode paysage pour le player
