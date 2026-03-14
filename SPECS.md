# Specs produit — Quieto

## Concept

Quieto est une application de méditation guidée **en français**, pensée pour rendre la méditation accessible à tous les niveaux. Contenu statique (audio embarqué) pour le MVP, sans backend.

## Fonctionnalités MVP

### Onboarding
- 3 slides d'introduction
- Bouton "Passer" disponible dès la slide 1
- Redirige vers Home après completion

### Home ✅
- Header : logo "Quieto" + salutation personnalisée "Bonjour, [prénom]" (via StorageService)
- Scroll horizontal de bulles de catégories ("Programmes disponibles") → `/category/:id`
- Carte "Priorité du moment" mise en avant (Actualité 🌍, bordure accent) → `/category/actualite`
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

| Catégorie | Emoji | Séances gratuites | Séances premium |
|---|---|---|---|
| Stress | 😤 | Respiration 4-7-8 (5min) | Body scan (15min) |
| Sommeil | 🌙 | Détente du soir (10min) | Visualisation (20min) |
| Focus | 🎯 | Pleine conscience (5min) | Méditation pomodoro (10min) |
| Anxiété | 💭 | Technique 5-4-3-2-1 (8min) | Méditation de l'arbre (12min) |
| Respiration | 🌬️ | Cohérence cardiaque (5min) | Respiration boîte (10min) |
| Confiance | 💪 | Affirmations positives (7min) | Visualisation du succès (12min) |
| Pleine conscience | 🧘 | Scan des sensations (10min) | Méditation du miroir (15min) |
| Actualité | 🌍 | Détox numérique (8min) | Ancrage face à l'incertitude (12min) |

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
- Badge "New !" sur la catégorie Actualité (bubble + list card)
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
