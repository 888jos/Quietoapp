# Specs produit — Quieto

## Concept

Quieto est une application de méditation guidée **en français**, pensée pour rendre la méditation accessible à tous les niveaux. Contenu statique (audio embarqué) pour le MVP, sans backend.

## Fonctionnalités MVP

### Onboarding
- 3 slides d'introduction
- Bouton "Passer" disponible dès la slide 1
- Redirige vers Home après completion

### Home
- Liste des catégories de méditation
- Chaque catégorie affiche ses séances avec durée
- Badge "Premium" sur les séances payantes
- Tap sur une séance → PlayerPage

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
| Gestion du stress | 🌊 | Respiration 4-7-8 (5min) | Body scan (15min) |
| Sommeil | 🌙 | Détente du soir (10min) | Visualisation (20min) |
| Concentration | 🎯 | Pleine conscience (5min) | Méditation pomodoro (10min) |
| Anxiété | 💚 | Technique 5-4-3-2-1 (8min) | Méditation de l'arbre (12min) |

## Design system

### Couleurs
| Token | Hex | Usage |
|---|---|---|
| `bgForest` | `#0D1F1A` | Fond principal |
| `cardForest` | `#1A2E27` | Surface des cartes |
| `sage` | `#7CAE9E` | Accent principal, CTA |
| `sageDim` | `#267CAE9E` | Éléments subtils (15% opacité) |
| `parchment` | `#F5F0E8` | Texte principal |
| `parchmentMuted` | `#99F5F0E8` | Texte secondaire (60% opacité) |

### Thème
- Dark only — pas de mode clair
- Material 3
- Pas de couleurs hardcodées en dehors de `AppColors`

## Monétisation

- Modèle freemium : 1 séance gratuite par catégorie
- Abonnement mensuel : 4,99 € / mois
- Intégration RevenueCat (`purchases_flutter`)
- Entitlement : `premium`
- Offering : `default`

## Roadmap post-MVP

- [ ] Intégration Firebase (auth, analytics)
- [ ] Téléchargement hors-ligne
- [ ] Notifications de rappel de méditation
- [ ] Statistiques avancées (streak, graphe hebdomadaire)
- [ ] CategoryDetailPage complète
- [ ] Favoris
- [ ] Mode paysage pour le player
