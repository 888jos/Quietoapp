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

## Pour aller plus loin (docs du projet)
- `SEANCES.md` — catalogue complet des 35 séances.
- `SPECS.md` — spécifications produit détaillées.
- `ARCHITECTURE.md` — structure technique du code.
- `DECISIONS.md` — choix techniques et pourquoi.
