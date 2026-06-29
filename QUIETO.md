# Quieto — c'est quoi ?

> Document de présentation. À donner tel quel à une IA (ou une personne) pour comprendre vite ce qu'est Quieto et où le projet va.
> Mainteneur : Cofonde · Version de l'app : **1.0.4** · Plateformes : **iOS + Android**

## En une phrase
**Quieto est une application de méditation guidée en français**, pensée pour rendre la méditation simple et accessible : des séances courtes, ancrées dans les vrais moments de la journée (un appel difficile, les transports, juste avant de dormir…).

## Pour qui / quel problème
Des francophones stressés, qui dorment mal, ou en surcharge mentale (boulot, actualité, émotions). Débutants comme habitués. Le pari : pas de jargon, pas de gamification compliquée — juste une voix qui guide et une ambiance calme.

## Le but
Devenir **l'app de méditation francophone de référence** (face à Petit BamBou, Calm, Headspace).
La différenciation : la **simplicité** et **l'ancrage dans le quotidien** — des micro-méditations (1 à 3 min) pour des situations concrètes, là où les concurrents proposent surtout des programmes longs et génériques.

## Ce que Quieto fait aujourd'hui
**Parcours utilisateur :**
Onboarding personnalisé (quelques questions sur ton état émotionnel + ton prénom) → Accueil personnalisé → Explorer les catégories → Écran de préparation → Lecteur audio (avec mini-lecteur qui suit l'utilisateur) → Profil avec statistiques (minutes méditées, séances terminées).

**Contenu :** 7 catégories, **35 séances** de 1 à 14 min (Express, Découverte, Stress & Anxiété, Sommeil, Respiration, Émotions, Actualité & Surcharge mentale). Liste complète dans `SEANCES.md`.

**Modèle économique :** freemium.
- **Gratuit** : la catégorie Découverte + les Express de base.
- **Premium** : tout le reste, via un abonnement à **4,99 €/mois**, avec **essai gratuit de 7 jours**.
- Paiements gérés par RevenueCat (App Store + Google Play).

**Technique :** app **Flutter** (un seul code pour iOS + Android). Les audios sont hébergés sur **Firebase Storage** et lus en streaming (donc, aujourd'hui, connexion requise pour écouter).

## Ce que Quieto va devenir (vision / prochaines étapes)
- **Écoute hors-ligne** — télécharger / mettre en cache les séances pour écouter sans connexion.
- **Plus de contenu** — de nouvelles séances et catégories ajoutées régulièrement.
- **Rappels & habitude** — notifications et séries (streaks) pour aider à méditer chaque jour.
- **Autres langues** — une version anglaise et une ouverture à l'international.
- **Louane** — un **compagnon IA** intégré à l'app : il discute avec l'utilisateur, lui recommande la bonne séance selon son humeur, et l'accompagne au quotidien. *(Vision — pas encore construit.)*

## Stack technique (pour une IA dev)
Flutter / Dart · Riverpod (état) · go_router (navigation) · just_audio + audio_service (lecture audio + contrôles écran verrouillé) · RevenueCat (`purchases_flutter`, abonnements) · Firebase Storage (audios) · shared_preferences (stockage local des préférences et de la progression).

## Direction artistique (design system)

> À lire avant de concevoir le moindre écran. Objectif : qu'une IA ou un designer produise une page **immédiatement cohérente** avec Quieto. Toutes les valeurs ci-dessous viennent du vrai code (`lib/core/theme/` et `lib/core/config/app_constants.dart`) — réutilise les constantes, n'invente pas de valeurs.

### Ambiance générale
**Nuit zen.** Fond bleu nuit profond, un seul accent turquoise lumineux, beaucoup d'espace, coins arrondis, animations douces et lentes. On vise le calme et l'apaisement — jamais l'agressif, le clignotant ou le criard. Référence d'esprit : un ciel étoilé paisible.

### Palette de couleurs (`lib/core/theme/app_colors.dart`)
| Rôle | Constante | Hex | Usage |
|------|-----------|-----|-------|
| Fond principal | `AppColors.background` | `#0A1628` | Fond de **tous** les écrans (bleu nuit) |
| Surface carte | `AppColors.cardSurface` | `#0D2137` | Cartes, champs, conteneurs surélevés |
| Accent | `AppColors.accent` | `#5CE0D8` | Turquoise — boutons, sélection, icônes clés, liens |
| Accent atténué | `AppColors.accentDim` | turquoise à **15 %** | Halos, bordures douces, pastilles, lignes |
| Texte principal | `AppColors.textPrimary` | `#FFFFFF` | Titres, texte fort |
| Texte secondaire | `AppColors.textMuted` | blanc à **60 %** | Sous-titres, descriptions, légendes |
| Erreur | `AppColors.error` | `#E07070` | Erreurs uniquement (corail doux) |

**Règle d'or :** fond toujours sombre, le turquoise est l'**unique** couleur d'accent et se **dose** (il guide l'œil vers l'action). Pas de second accent, pas de fond clair.

### Typographie (`lib/core/theme/app_text_styles.dart`)
Police : **SF Pro Display**. Styles prêts à l'emploi :
- `displayLarge` — 32 / w700 — gros titre d'écran
- `titleLarge` — 22 / w600 · `titleMedium` — 17 / w600 — titres de section / carte
- `bodyLarge` — 16 / w400 — corps principal · `bodyMedium` — 14 / w400 (déjà en muted) — corps secondaire
- `labelLarge` — 16 / w600 — texte de bouton
- `caption` — 12 / w400 (muted) — légendes/mentions · `badge` — 12 / w500 (turquoise) — petits badges
Astuce : pour qu'un titre ou un prix tienne **sur une seule ligne**, l'envelopper dans `FittedBox(fit: BoxFit.scaleDown, child: Text(..., maxLines: 1))`.

### Espacements & arrondis (`lib/core/config/app_constants.dart`)
- Espacements : `spacingXs 4` · `spacingSm 8` · `spacingMd 16` · `spacingLg 24` · `spacingXl 32` · `spacingXxl 48`.
- Rayons : `radiusSm 8` · `radiusMd 12` · `radiusLg 20` · `radiusXl 28`. Boutons & cartes ≈ `radiusLg`.

### Composants réutilisables (`lib/core/ui/`)
- **`AppButton`** — variantes `primary` (plein turquoise, texte sombre), `secondary` (contour turquoise), `ghost`. Gère `isLoading`, `leadingIcon`, retour haptique intégré. **Toujours** l'utiliser pour les actions.
- **`AppCard`** — carte `cardSurface` arrondie, padding par défaut `spacingMd`.
- **`AppScaffold`** — ossature d'écran avec le bon fond.
Réutiliser ces composants plutôt que de redessiner des boutons/cartes à la main.

### Motifs visuels signature
- **Ciel étoilé animé** : étoiles blanches qui **scintillent** (cœur vif + léger halo flou) + **étoiles filantes turquoise** occasionnelles. Dessiné en `CustomPainter` (réf. `lib/features/louane/presentation/widgets/louane_personnage.dart` → `CielEtoileFond`, et le hero du paywall). C'est LA texture de fond emblématique.
- **Orbes lumineux** : cercle **plein turquoise** + `boxShadow` turquoise diffuse (glow). Sert d'icône-héros (avec une icône sombre au centre, ex. `Icons.self_improvement`).
- **Halos** : `RadialGradient` de `accent` (≈14 %) vers transparent, derrière un élément, pour le faire « rayonner ».
- **Pastilles** : petits ronds `accentDim` ou `accent` portant une icône (avantages, étapes).
- **Timeline verticale** : étapes reliées par une fine ligne `accentDim` (voir le paywall) — idéale pour expliquer un déroulé.
- **Louane** : le compagnon est un **personnage dessiné en code** (visage rond turquoise, yeux qui clignent, sourire), pas une image.

### Animations
- Durées : `animFast 200` · `animNormal 350` · `animSlow 600` ms. Rien de brusque.
- Courbes : `easeOutCubic` (entrées/montées), `easeInOut` (fondus), `easeOutBack` (petit rebond ludique).
- Transitions de page : **fondu doux** (cf. `lib/core/theme/app_theme.dart`). Privilégier `CustomPaint`/widgets animés aux GIF/grosses images (perf + cohérence).

### Ton & rédaction
**Français, tutoiement** (« tu »), chaleureux et zen. Phrases courtes, zéro jargon. Emojis avec **parcimonie** dans les titres/CTA (✨ 🌙 🧘 🔔), jamais dans le texte lu à voix haute. Exemple de voix : « Prends un moment pour toi », « Commencer mon essai gratuit ».

### À éviter
Fonds clairs · un 2ᵉ accent coloré · coins carrés · ombres dures/noires · texte gris peu lisible · animations rapides ou qui clignotent · grosses illustrations lourdes quand un dessin en code suffit.

## Pour aller plus loin (docs du projet)
- `SEANCES.md` — catalogue complet des 35 séances.
- `SPECS.md` — spécifications produit détaillées.
- `ARCHITECTURE.md` — structure technique du code.
- `DECISIONS.md` — choix techniques et pourquoi.
