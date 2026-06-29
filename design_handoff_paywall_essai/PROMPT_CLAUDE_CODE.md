# Prompt prêt à coller dans Claude Code

> Contexte : l'app Flutter « Quieto » est **déjà en production** et **déjà branchée à
> RevenueCat**. Il s'agit UNIQUEMENT de **remplacer l'UI du paywall** par le nouveau design.
> Colle le bloc ci-dessous dans Claude Code, à la racine de ton repo, avec le dossier
> `design_handoff_paywall_essai/` présent. Adapte les ▢ entre crochets.

---

Tu travailles dans mon app **Flutter** « Quieto » (méditation), **déjà en production**.
RevenueCat est **déjà intégré et opérationnel** (offerings, entitlement, achat, restauration
fonctionnent). Je veux **uniquement remplacer l'écran de paywall** par un nouveau design —
**c'est un swap d'UI**, pas une nouvelle intégration de paiement.

## 1. Avant tout : lis l'existant
- Parcours `lib/` et **repère l'écran de paywall actuel** + le **service d'abonnement**
  (la classe/provider qui appelle RevenueCat : offerings, `purchasePackage`,
  `restorePurchases`, l'entitlement premium).
- Repère mon **pattern d'état** (Provider/Riverpod/Bloc…) et mon **thème**.
- **Réutilise tout ça tel quel.** Ne touche pas à la config RevenueCat, aux clés, ni aux
  stores. Tu ne fais que reconstruire la couche visuelle et la rebrancher sur l'existant.

## 2. Le design est fourni EN CODE (Flutter) — à intégrer tel quel
Dossier `design_handoff_paywall_essai/` :
- **`paywall_screen.dart`** — le paywall **déjà écrit en Flutter, au pixel près** : ciel
  étoilé + étoiles filantes, orbe animé, sélecteur Annuel/Mensuel qui glisse, timeline,
  carte tarif, CTA, réassurance, restaurer, légal. **Toutes les constantes (couleurs,
  tailles, espacements, courbes d'animation) sont exactes.** C'est la **source de vérité visuelle**.
- `Quieto Paywall - Sereine.dc.html` (+ `support.js`) — le prototype d'origine, **à ouvrir
  dans un navigateur comme cible visuelle** pour comparer ton rendu.
- `README.md` — la même spec en tokens (référence).

**Consigne : intègre `paywall_screen.dart` tel quel. Ne le redessine pas, ne réinterprète
pas les valeurs, ne change aucune taille / marge / couleur / courbe.** Le 1er essai avait
divergé parce qu'on demandait de *recréer* le design ; cette fois le visuel est livré en
code — tu ne fais que **l'adapter à mon projet et le brancher**.

Seules adaptations autorisées :
- **Police** : le fichier référence la famille `HankenGrotesk`. Branche-la sur ma config
  (asset déjà présent, ou `google_fonts` → `GoogleFonts.hankenGrotesk`). Garde la même police.
- **Icônes** : le fichier utilise les `Icons.*` Material intégrés (compile sans dépendance).
  Pour le rendu *exact* des Material Symbols Rounded, remplace par le package
  `material_symbols_icons` (`Symbols.self_improvement`, `Symbols.lock_open`, `Symbols.notifications`,
  `Symbols.workspace_premium`, `Symbols.lock`) — mêmes glyphes.
- **Données** : voir §4 (prix / dates / essai depuis RevenueCat). Les `PaywallOffer` par
  défaut du fichier sont les placeholders du design.
- **Chrome de maquette** : le bezel, l'encoche, la barre « 9:41 » et le home-indicator du
  prototype sont **dessinés par l'OS** — volontairement absents du `.dart`. N'essaie pas de
  les recréer.

## 3. Vérifie l'exactitude (boucle de comparaison — l'étape qui manquait)
Après intégration, **compare ton écran au prototype, côte à côte** :
1. Ouvre `Quieto Paywall - Sereine.dc.html` dans un navigateur (cadre 393 × 858).
2. Lance l'app sur un simulateur de largeur ~393.
3. Corrige **chaque écart** (police, espacements, rayons, ombres, timing d'animation)
   jusqu'à ce que ce soit **identique**. Le `.dart` contient déjà les bonnes valeurs : si un
   écart apparaît, c'est l'environnement (`ThemeData`/`textTheme` qui impose un
   `letterSpacing` ou une police par défaut) — **neutralise-le**, ne modifie pas les
   constantes du design.

## 4. Branchement sur l'existant
- **Prix, prix /mois et durée d'essai** : lis-les depuis les **offerings RevenueCat déjà
  chargés** (packages annuel/mensuel). **Rien en dur.** Calcule « Économise X % » =
  `1 − prixAnnuel/(prixMensuel×12)`. Calcule les dates de la timeline depuis `DateTime.now()`
  + durée d'essai du package.
- Si l'utilisateur n'est plus **éligible à l'essai**, masque le wording « X jours gratuits »
  et adapte le CTA (« S'abonner »).
- **CTA** → appelle ma **méthode d'achat existante** avec le package sélectionné. Gère
  loading / succès (entitlement premium actif → ferme le paywall) / annulation (silencieuse)
  / erreur.
- **« Restaurer mes achats »** → appelle ma **restauration existante** + feedback.
- Garde le **gating premium existant** intact.

## 5. Garde-fous
- Ne réécris pas mon service d'abonnement ; **consomme-le**. Si l'UI a besoin d'une donnée
  qu'il n'expose pas (ex. durée d'essai du package), ajoute un petit getter sans casser le reste.
- Remplace proprement l'ancien écran (et nettoie le code mort si l'ancien paywall n'est plus utilisé).
- Respecte mes conventions de nommage/dossiers.

## 6. Process
Commence par me **proposer un plan** : fichiers à créer/modifier, où tu branches les
offerings et les méthodes d'achat/restauration existantes. Attends mon feu vert avant de coder.
