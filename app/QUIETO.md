# Quieto — c'est quoi ?

> Document de présentation. À donner tel quel à une IA (ou une personne) pour comprendre vite ce qu'est Quieto et où le projet va.
> Mainteneur : Cofonde · Version de l'app : **1.0.28+39** (builds envoyés à App Store Connect et à la Play Console par Paul le 28/09/2026 ; la **1.0.27 est publiée sur l'App Store** — la fiche affiche « 1.27 », en ligne depuis le 25/09) · Plateformes : **iOS + Android** (la fiche Google Play répond de nouveau, relevé le 28/09/2026 ; l'app en avait été retirée le 05/08)
> ⚠️ À remettre à jour à chaque release (version, fonctionnalités, prix, contenu). (maj 28/09/2026)
> 📁 Depuis le 26/09/2026, tout Quieto vit dans un seul dépôt, `~/Desktop/dev/Quieto` : ce fichier est dans `app/`, le backend dans `backend/`, le journal dans `docs/`.

## En une phrase
**Quieto est une application de méditation guidée en français**, pensée pour rendre la méditation simple et accessible : des séances courtes, ancrées dans les vrais moments de la journée (un appel difficile, les transports, juste avant de dormir…), et **Louane**, une compagnonne IA qui accompagne l'utilisateur au quotidien.

## Pour qui / quel problème
Des francophones stressés, qui dorment mal, ou en surcharge mentale (boulot, actualité, émotions). Débutants comme habitués. Le pari : pas de jargon, pas de gamification compliquée — juste une voix qui guide et une ambiance calme.

## Le but
Devenir **l'app de méditation francophone de référence** (face à Petit BamBou, Calm, Headspace).
- **Phase 1 : le marché français** — prendre la place de n°2 français (vacante), viser 30-40 k$/mois.
- **Phase 2 : l'international.**

La différenciation : la **simplicité**, **l'ancrage dans le quotidien** (micro-méditations de 1 à 3 min pour des situations concrètes, là où les concurrents proposent des programmes longs et génériques) et **Louane**, le compagnon IA qu'aucun concurrent n'a.

## La fonctionnalité principale : Louane
Une **compagnonne IA** intégrée à l'app — un personnage dessiné en code (visage rond turquoise, yeux qui clignent, sourire), pas une image. Elle :
- **discute** avec l'utilisateur (chat) et recommande la bonne séance selon son humeur ;
- **compose le « programme »** : un parcours personnalisé de 7 jours, avec étoiles de progression.

Côté serveur : Cloud Functions `louane`, `genererParcours` et `accueilOnboarding` — **tout sur GPT-5.6 Luna (OpenAI) depuis le 14/08/2026** (Voix, Veilleur sécurité, Mémoire ; la Plume a été supprimée). C'est la meilleure surface de conversion de l'app — Louane reste accessible aux utilisateurs gratuits, c'est voulu.

*(maj 28/09/2026)* Le modèle se règle en un seul endroit, la constante `MODELE` de `backend/functions/index.js`. **GPT-6 Luna a été essayé du 26 au 28/09/2026** (moitié prix, réponses plus courtes) puis abandonné : Paul préfère la voix de la 5.6. Deux filets serveur ajoutés le 28/09 : aucun caractère d'une autre écriture dans une bulle (`sansEcritureEtrangere`), et à un « salut » qui répond à sa question d'ouverture, Louane rend le salut et repose la même question. Côté app (1.0.28) : la page Louane ne saccade plus (voile flou de l'en-tête passé de 14 à 6 couches).

*(maj 28/09/2026, relevé dans le code)* Limites de Louane : **40 messages découverte offerts** au total pour un utilisateur gratuit, puis Quieto Premium (`GRATUIT_MAX`) ; **100 messages par jour** pour un abonné (`PLAFOND_JOUR_ABONNE`). Le Veilleur (sécurité) tourne toujours, même au-delà des limites.

Depuis la 1.0.20, le **jour 1 du tout premier programme est toujours « Ma première méditation »** (quasi personne n'a jamais médité) — flag `premierParcours` envoyé par l'app, verrou `forcerPremiereMeditation` côté serveur. Et depuis le 30/08/2026 (décision Paul, backend `5b5dcee` déployé), **les séances flash « Une minute pour toi » (1-3 min) ne vont JAMAIS dans un programme** : trop courtes pour porter un jour — le catalogue montré au modèle est filtré et un verrou serveur remplace tout id express.

## Ce que Quieto fait aujourd'hui
**Parcours utilisateur :**
Onboarding personnalisé (questions sur ton état émotionnel + prénom + proposition Apple Santé) → compte Apple / Google ou « Continuer sans compte » → Accueil personnalisé → Louane (chat + programme 7 jours) ou Explorer les catégories → Lecteur audio (contrôles sur écran verrouillé et centre de contrôle — le mini-lecteur in-app a été supprimé le 28/08/2026 : pour rouvrir l'écran de séance, on repasse par sa carte) → Profil avec statistiques (minutes méditées, séances terminées) et carte de partage.

**Contenu :** 7 catégories, **35 séances** de 1 à 14 min (Express « Une minute pour toi », Découverte, Actualité & Surcharge mentale, Stress & Anxiété, Sommeil, Respiration, Émotions). Le catalogue est défini dans `lib/features/explore/data/explore_repository.dart`. Depuis le 26/08/2026, **chaque séance a une cover illustrée style gouache** (`assets/images/sessions/`, WebP) et **chaque catégorie son bandeau paysage** (`assets/images/categories/`, 7 fichiers WebP) — voir `DIRECTION-ARTISTIQUE.md` et `PROMPTS-VISUELS.md`.

**Apple Santé / Health Connect :** les minutes de pleine conscience sont enregistrées dans l'app Santé du téléphone.

**Modèle économique :** freemium.
- **Gratuit** : la catégorie Découverte + les Express de base, et Louane (~~non bridée~~ *maj 28/09/2026 : 40 messages découverte offerts, puis Premium*).
- **Premium** : tout le reste — **essai gratuit de 7 jours**, puis **89 €/an** ou **16,90 €/mois**. Stratégie assumée : l'annuel d'abord (le mensuel est volontairement cher pour ancrer le prix).
- Paiements gérés par RevenueCat (App Store + Google Play).
- *(maj 28/08/2026, 1.0.20)* Le paywall s'affiche **à chaque démarrage à froid** pour les non-abonnés (montée douce sous voile, `5acdfff` + `29f2b65`). L'écran du mur lui-même ne bouge pas (règle « le mur ne se touche pas », décision Paul du 25/08).

**Analytics :** la « Vigie », outil maison — événements envoyés par l'app à la Cloud Function `trace` → Firestore, webhook RevenueCat pour l'issue des essais, dashboard local (`~/Desktop/dev/Quieto IA/analytics`, hors du dépôt unique).

**Technique :** app **Flutter** (un seul code pour iOS + Android). Audios hébergés sur **Firebase Storage**, lus en streaming (connexion requise). Backend : Cloud Functions (`../backend` — avant le 26/09/2026 : `~/dev/quieto-backend`).

**Quieto Entreprise (B2B)** *(maj 28/09/2026)* : un employeur peut offrir le Premium à ses salariés. L'entreprise paie sur le web par Stripe (site `sites/entreprise/`), reçoit un code, et le salarié le saisit dans le profil (« Accès offert par mon entreprise », `acces_entreprise_sheet.dart`, fonction `accesEntreprise`). Détail : `../docs/PASSATION-B2B-2026-09-24.md`.

## Ce que Quieto va devenir (vision / prochaines étapes)
- **Faire écouter la première séance** — chantier n°1 depuis l'analyse Vigie du 25/08/2026 (`AMELIORATIONS.md`) : 88 % des installés n'écoutent jamais une méditation en entier. Trois pistes retenues : notification proposée en fin d'onboarding, programme 7 jours en haut de la home, relances J+1/J+3 pendant l'essai. ⚠️ Le mur de paiement, lui, ne se touche pas (décision Paul, 25/08).
- **Écoute hors-ligne** — télécharger / mettre en cache les séances pour écouter sans connexion.
- **Plus de contenu** — de nouvelles séances et catégories ajoutées régulièrement.
- **Rappels & habitude** — notifications et séries (streaks) pour aider à méditer chaque jour.
- **International** (phase 2) — version anglaise et ouverture au-delà du marché français.

## Stack technique (pour une IA dev)
Flutter / Dart · Riverpod (état) · go_router (navigation) · just_audio + audio_service (lecture audio + contrôles écran verrouillé) · RevenueCat (`purchases_flutter`, abonnements) · Firebase — projet `quieto-06` : Auth (Apple / Google / anonyme), Cloud Functions, Storage (audios), App Check · shared_preferences (préférences et progression locales).

## Direction artistique (design system)

> À lire avant de concevoir le moindre écran. Objectif : qu'une IA ou un designer produise une page **immédiatement cohérente** avec Quieto. Toutes les valeurs ci-dessous viennent du vrai code (`lib/core/theme/` et `lib/core/config/app_constants.dart`) — réutilise les constantes, n'invente pas de valeurs.
> ⚠️ **maj 26/08/2026** : la DA a évolué — les illustrations (covers de séances, bandeaux de catégorie, cartes de la home) sont désormais des **gouaches générées** pour tuer le « look IA ». Le parti pris complet est dans **`DIRECTION-ARTISTIQUE.md`** (audit du 25/08) et la méthode de génération dans **`PROMPTS-VISUELS.md`** — les lire avant de produire la moindre image.

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
- **Pilules flottantes** *(maj 28/08/2026)* : la barre de nav et la saisie Louane sont des **pilules translucides bleu nuit sur flou** (nav : `background` à 75 % ; saisie : `#122036` à 85 %), sans bordure — le contenu défile **derrière** elles, seuls les ovales flottent.

### Animations
- Durées : `animFast 200` · `animNormal 350` · `animSlow 600` ms. Rien de brusque.
- Courbes : `easeOutCubic` (entrées/montées), `easeInOut` (fondus), `easeOutBack` (petit rebond ludique).
- Transitions de page : **fondu doux** (cf. `lib/core/theme/app_theme.dart`). Pour l'animation : `CustomPaint`/widgets animés (voire shaders GPU — l'aurore boréale de la home, `shaders/aurora.frag`, maj 26/08) plutôt que GIF. Pour l'illustration statique : les gouaches (voir `DIRECTION-ARTISTIQUE.md`).

### Ton & rédaction
**Français, tutoiement** (« tu »), chaleureux et zen. Phrases courtes, zéro jargon. Emojis avec **parcimonie** dans les titres/CTA (✨ 🌙 🧘 🔔), jamais dans le texte lu à voix haute. Exemple de voix : « Prends un moment pour toi », « Commencer mon essai gratuit ».

### À éviter
Fonds clairs · un 2ᵉ accent coloré · coins carrés · ombres dures/noires · texte gris peu lisible · animations rapides ou qui clignotent · toute image au rendu « généré par IA » (dégradés lisses, halos, formes vectorielles molles — voir `DIRECTION-ARTISTIQUE.md`, maj 26/08).

## Pour aller plus loin (docs du projet)
- `lib/features/explore/data/explore_repository.dart` — le catalogue complet des 35 séances (l'ancien `SEANCES.md` n'existe plus).
- `SPECS.md` — spécifications produit détaillées.
- `ARCHITECTURE.md` — structure technique du code.
- `DECISIONS.md` — choix techniques et pourquoi.
- `AMELIORATIONS.md` — backlog produit conversion & rétention (chiffres Vigie du 25/08/2026).
- `DIRECTION-ARTISTIQUE.md` + `PROMPTS-VISUELS.md` — parti pris visuel gouache et méthode de génération des images.
- `../docs/JOURNAL-QUIETO.md` — journal de bord (état du projet, chiffres clés, prochaines actions). *(maj 28/09/2026 : dans le dépôt unique ; avant : `~/dev/JOURNAL-QUIETO.md`)*
- `../backend/README.md` — les fonctions du serveur, le banc de voix.
