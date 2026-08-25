# 📈 Améliorations — conversion & rétention Quieto

> Backlog des chantiers **produit** (pas des bugs — pour ça voir `BUGS_A_CORRIGER.md`).
> Chaque fiche part d'un chiffre mesuré dans la Vigie, pas d'une intuition.
> Ouvert le 25/08/2026 à partir de l'analyse des 207 000 événements des 30 derniers jours (4 298 personnes).

---

## 📊 Le constat qui cadre tout (mesuré le 25/08/2026, fenêtre 30 j)

| Étape | Personnes | Taux |
|---|---|---|
| Ouvrent l'app (95 % de nouveaux) | 4 298 | — |
| Finissent l'onboarding | 4 000 | **97,5 %** ✅ |
| Arrivent sur la home | 3 243 | 75 % |
| Ouvrent une catégorie | 1 728 | 53 % |
| **Lancent** une séance | 738 | 23 % |
| **Terminent** une séance | 392 | **12 %** ⚠️ |
| Reviennent un 2ᵉ jour | 747 | **17 %** ⚠️ |

**La plus grosse fuite : entre la home et la première séance écoutée.**
**88 % des gens qui installent Quieto n'écoutent jamais une méditation en entier.**
L'onboarding et le paywall d'entrée, eux, marchent (le paywall d'onboarding fait 178 des 288 achats).

Où va la personne après la home : **catégorie 45 %**, **Louane 40 %**, profil 8 %. Elle tape une séance
au bout de ~2 min. Louane est massivement utilisée (2 427 personnes, médiane 5 messages).

Ce que ça coûte sur l'essai — croisement essai × écoute :

| Séances terminées pendant l'essai | Essais | Annulés |
|---|---|---|
| 0 | 119 | **57 %** |
| 1 | 82 | 55 % |
| **2+** | 62 | **37 %** |

**45 % de ceux qui donnent leur carte n'écoutent jamais une séance en entier**, et annulent
en médiane **32 h** après. Écouter 2 séances = **−20 points d'annulation**.

> ⚠️ Décision de Paul (25/08/2026) : **on ne touche pas au mur de paiement**, il est validé.
> Les trois chantiers ci-dessous n'y touchent pas.

---

## 🔧 Les trois chantiers (par impact)

### 1. Demander la notification à la fin de l'ONBOARDING, pas à la fin d'une séance
- **Pour l'utilisateur** : juste après le questionnaire, quand il est encore motivé —
  « à quelle heure veux-tu ton moment de calme ? » — au lieu d'après une séance qu'il n'écoutera jamais.
- **Le chiffre** : le rappel n'est proposé **qu'à la fin du lecteur** → **258 propositions pour 4 000 arrivées**.
  Les 88 % qui n'écoutent rien ne se voient JAMAIS proposer de notification : aucun canal pour les rappeler.
  D'où les 83 % qui ne reviennent jamais.
- **Fichier** : `lib/features/player/presentation/player_page.dart` (~63-68) → à déplacer/dupliquer
  vers la fin de l'onboarding (`onboarding_trust` ou juste avant la home).
  Service existant : `lib/core/services/notification_service.dart`.
- **Effort** : petit. **Impact : le plus élevé du lot** (débloque le seul canal de retour).

### 2. Le programme 7 jours en haut de la home, avant la grille de catégories
- **Pour l'utilisateur** : il arrive et voit une porte ouverte (« Jour 1 ») au lieu d'une grille
  de cadenas. Il écoute, il vit l'app — le mur arrive après, quand il sait ce qu'il achète.
- **Le chiffre** : **22 séances sur 23 sont verrouillées** (`explore_repository.dart` : 22 × `isPremium: true`,
  1 × `false` = `decouverte`). Sur ceux qui ouvrent une catégorie, **51 % tapent une séance verrouillée**
  et se prennent le paywall avant d'avoir rien écouté. **71 % des lancements** se concentrent sur
  `decouverte` — la seule gratuite, 3 séances.
- **Fichiers** : `lib/features/explore/presentation/category_detail_page.dart` (~115-125, le verrou),
  `lib/features/explore/data/explore_repository.dart` (le marquage premium), la home.
- **Effort** : moyen (choix éditorial autant que technique — combien de gratuit ?).

### 3. Relancer pendant l'essai, à J+1 et J+3
- **Pour l'utilisateur** : une notification le lendemain (« ta séance du jour t'attend ») et une le 3ᵉ jour.
  Le but n'est pas de vendre : **c'est l'écoute qui vend**.
- **Le chiffre** : 0 séance → 57 % d'annulation, 2+ séances → 37 %. Avec 263 essais/mois,
  20 points = **≈ +50 abonnés/mois** à trafic constant.
- **Dépend de** : le chantier 1 (sans permission de notification, rien à relancer).
- **Effort** : moyen (planification locale suffit, pas besoin de push serveur).

---

## 📌 Réserves de fiabilité (à savoir avant de recompter)
- Le **webhook RevenueCat ne date que du 11/08/2026** : `essai_converti` (5) **sous-compte** — l'issue
  d'un essai tombe 7 j après son démarrage. Ne pas en tirer un taux de conversion ;
  le **taux d'annulation** est la mesure fiable aujourd'hui.
- Un appareil en **1.0.9** pollue les stats avec **1 974 affichages de paywall en boucle**
  (source `seance`, 7 sessions, vigie `v_97ac6e10006a6e01`) — artefact isolé, écarté de l'analyse.
  À re-regarder si le motif réapparaît sur une version récente.
- Les essais ont **explosé depuis le 20/08** (23, 70, 60, 71, 33/jour contre ~32/mois en juillet) :
  les chiffres d'annulation portent surtout sur cette vague récente.
