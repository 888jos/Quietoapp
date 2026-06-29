# Handoff — Paywall « Comment marche ton essai » (Quieto)

## Overview
Écran de paywall (mur d'abonnement) pour l'app de méditation **Quieto**. Il présente le
déroulé de l'essai gratuit (« trial timeline ») puis propose de démarrer l'essai sur un
forfait **Annuel** ou **Mensuel**. Objectif : convertir en rassurant l'utilisateur sur le
fait qu'il ne sera pas débité par surprise.

## À propos des fichiers de design
Le design est livré **en code Flutter, au pixel près** : **`paywall_screen.dart`** est la
**source de vérité visuelle** (tous les tokens, tailles, espacements et courbes d'animation
exacts). À **intégrer tel quel** dans le projet — **ne pas le recréer ni réinterpréter les
valeurs**. Le HTML est conservé comme **cible de comparaison** visuelle. Le paiement se
branche sur l'infrastructure d'abonnement existante (RevenueCat, voir plus bas).

Fichiers inclus :
- `paywall_screen.dart` — **le paywall en Flutter, prêt à intégrer** (pixel-exact, animations comprises).
- `Quieto Paywall - Sereine.dc.html` + `support.js` — prototype d'origine, à ouvrir dans un
  navigateur comme cible visuelle (les deux fichiers restent ensemble).
- `PROMPT_CLAUDE_CODE.md` — **prompt prêt à coller** dans Claude Code (contexte + paiement).

## Fidélité
**Haute fidélité (hifi).** Couleurs, typo, espacements et interactions sont **définitifs et
fournis en code** dans `paywall_screen.dart` — l'**intégrer tel quel**, sans modifier les
constantes. **Exception importante :** les **prix et dates affichés sont des placeholders**
— en production ils doivent venir du store (via RevenueCat), localisés. Voir « Données
dynamiques ».

---

## Écran : Paywall essai

### Layout (de haut en bas)
Cadre téléphone 393 × 858, fond `#0A1628`, coins 46px. Padding intérieur `14px 22px 26px`.
Une seule colonne verticale (flex column) :

1. **Status bar** (hauteur 34) — heure + icônes réseau (chrome de maquette, à retirer dans l'app réelle, l'OS le dessine).
2. **Ciel étoilé** — calque absolu en haut (hauteur ~360), ~130 étoiles scintillantes générées + 3 **étoiles filantes** (dont une turquoise), fondu dégradé vers le bas (masque, transparent à 85%).
3. **Orbe de méditation** — bloc 128 de haut ; cercle turquoise 100×100 avec icône `self_improvement`, halo radial 200, animations douces (flottement + halo).
4. **Titre** « Comment marche ton essai » + **sous-titre** « 7 jours gratuits, puis tu décides. »
5. **Sélecteur segmenté** Annuel / Mensuel — pastille turquoise qui **glisse** (0,34 s).
6. **Timeline d'essai** — 3 étapes, pastille d'icône 42×42 + ligne de liaison dégradée.
7. **Carte tarif** — bloc arrondi 18px, fond `#0D2137`, bord turquoise.
8. **Espace flexible** (pousse le bloc d'action en bas).
9. **Bloc d'action** — ligne de réassurance + CTA + Restaurer + liens légaux.
10. **Home indicator** (chrome de maquette).

### Composants & tokens

**Couleurs**
- Fond app : `#0A1628`
- Surfaces (carte, sélecteur) : `#0D2137`
- Accent turquoise : `#5CE0D8`
- Texte sur turquoise : `#0A1628`
- Texte principal : `#FFFFFF`
- Texte secondaire : `rgba(255,255,255,.6)` / `.55` / `.45` / `.4`
- Bords turquoise : `rgba(92,224,216,.16→.22)`
- Étoile turquoise : `#5CE0D8`, étoiles blanches : `#FFFFFF`

**Typographie** — police **Hanken Grotesk** (Google Fonts), fallback SF Pro / système. Icônes : **Material Symbols Rounded**.
- Titre : 28px / 700 / line-height 1.1 / letter-spacing -0.02em / centré
- Sous-titre : 15px / 400 / `rgba(.6)`
- Onglets : 15px / 600
- Étape — titre : 16.5px / 600 ; description : 13px / `rgba(.6)`
- Carte — « X jours gratuits » : 15.5px / 700 ; sous-ligne : 12.5px / `rgba(.55)` ; chiffre /mois : 19px / 800 turquoise ; « par mois » : 11px / `rgba(.42)` ; badge : 10.5px / 700 turquoise sur `rgba(92,224,216,.14)`, radius 9
- CTA : 16px / 700, texte `#0A1628` sur `#5CE0D8`, padding 16, radius 20, ombre `0 12px 30px -8px rgba(92,224,216,.55)`
- Réassurance : 12px / `rgba(.45)` (icône cadenas)
- Restaurer : 14px / 600 turquoise
- Légal : 12px / `rgba(.4)` souligné

**Icônes timeline** : `lock_open` (étape 1), `notifications` (étape 2), `workspace_premium` (étape 3), turquoise, dans pastille `rgba(92,224,216,.14)` bord `.22`.

### Contenu exact (copie)

**Vue ANNUEL (par défaut)**
- Titre : « Comment marche ton essai »
- Sous-titre : « 7 jours gratuits, puis tu décides. »
- Étape 1 — « Aujourd'hui » / « Débloque toutes les séances et Louane, en illimité. »
- Étape 2 — « Dans 5 jours » / « On te prévient avant la fin de l'essai. »
- Étape 3 — « Dans 7 jours » / « Débité le 3 juillet, annulable à tout moment. »
- Carte : « 7 jours gratuits » + badge « Économise 58 % » · « facturé 59,90 € par an » · chiffre « 4,99 € » / « par mois »
- Réassurance : « Sans engagement · annulable à tout moment »
- CTA : « Commencer mon essai gratuit »
- « Restaurer mes achats » · « Conditions » · « Confidentialité »

**Vue MENSUEL**
- Sous-titre : « 3 jours gratuits, puis tu décides. »
- Étape 2 — « Demain » · Étape 3 — « Dans 3 jours » / « Débité le 29 juin, annulable à tout moment. »
- Carte : « 3 jours gratuits » (pas de badge) · « facturé chaque mois, sans engagement » · chiffre « 11,90 € » / « par mois »

### Interactions & animations
- **Sélecteur Annuel/Mensuel** : pastille turquoise qui glisse, transition `transform .34s cubic-bezier(.45,.05,.25,1)`, couleur des libellés en fondu `.28s`. Le choix met à jour : sous-titre (7/3 jours), dates des étapes, et toute la carte tarif.
- **CTA** : feedback tactile à l'appui — `transform: scale(.97)` + ombre resserrée, transition `.16s`.
- **Ciel** : scintillement en boucle ; étoiles filantes rapides (~1,5 s) et espacées (délais 1,5 / 7 / 12 s).

### Données dynamiques (⚠️ ne pas coder en dur)
En production, ces valeurs viennent de **RevenueCat (Offerings)** et sont **localisées** par le store :
- Prix annuel / mensuel et équivalent /mois.
- Pourcentage d'économie (calculé : `1 − prixAnnuel / (prixMensuel × 12)`).
- Durée de l'essai (7 j / 3 j) → vient de l'offre d'introduction du store.
- Les **dates de la timeline** se calculent : `aujourd'hui`, `aujourd'hui + (durée − 2j)` (rappel), `aujourd'hui + durée` (débit).
- L'éligibilité à l'essai (l'utilisateur a-t-il déjà consommé l'essai ?) vient de StoreKit/RevenueCat → si non éligible, masquer le wording « X jours gratuits ».

## State
- `selectedPlan` : `annual | monthly` (défaut `annual`).
- `offerings` / `packages` : chargés depuis RevenueCat au montage.
- `isPurchasing`, `isRestoring`, `error` : états de chargement/erreur du CTA et de Restaurer.
- `isPremium` (entitlement actif) : pour fermer le paywall et débloquer le contenu.

## Paiement — intégration existante (swap d'UI uniquement)
L'app est **déjà en production et branchée à RevenueCat**. Il s'agit d'un **simple
remplacement de l'UI du paywall** : réutiliser le service d'abonnement existant (offerings,
packages annuel/mensuel, entitlement, achat, restauration). **Ne pas reconfigurer les stores
ni RevenueCat.** Brancher le CTA sur la méthode d'achat existante, le lien « Restaurer » sur
la restauration existante, et afficher prix + durées d'essai depuis les offerings déjà chargés.
Voir `PROMPT_CLAUDE_CODE.md`.

## Files
- `paywall_screen.dart` — **le paywall en Flutter, pixel-exact, prêt à intégrer** (source de vérité visuelle).
- `Quieto Paywall - Sereine.dc.html` — prototype d'origine (cible de comparaison ; nécessite `support.js`).
- `support.js` — runtime du prototype (référence uniquement, pas pour l'app).
