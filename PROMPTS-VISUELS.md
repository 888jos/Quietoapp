# Prompts visuels Quieto — à donner à l'IA d'images

> Mode d'emploi : copier **le SOCLE** + **UN sujet**, dans cet ordre, dans le
> même prompt. Le socle ne change JAMAIS d'une image à l'autre — c'est lui qui
> garantit que les 40 images forment une série et pas une collection.
> Générer en **carré 2048×2048** (sauf mention contraire).

---

## ⚠️ Règle d'or
**Choisir UN médium au début et ne plus en changer.**
Deux options, les deux collent aux références :

- **A — Crayon de couleur** : traits directionnels visibles, grain de papier,
  couleurs saturées superposées. (référence 1 : le ciel bleu aux palmiers)
- **B — Gouache mate** : aplats opaques, texture de pinceau, bords légèrement
  irréguliers, palette très réduite. (références 2 et 3 : la lune, la colline)

👉 Recommandation : **B (gouache)**. Plus lisible en petit format (vignettes de
liste), plus facile à reproduire de manière constante, et le texte blanc passe
mieux dessus. Le crayon est plus beau en grand mais devient du bruit en 120 px.

---

## 🩸 Deux pièges vérifiés en test (25/08/2026)

**1. Ne JAMAIS écrire « paper grain » ou « on textured paper ».**
Gemini le comprend comme « photographie d'une feuille de papier posée sur une
table » : il rend une marge blanche énorme et une ombre portée. Le mot est banni
du socle, remplacé par le bloc FULL BLEED + la liste de négatifs.

**2. Même corrigé, il reste un liseré blanc de 2-4 % sur les bords.**
Le coup de pinceau ne va pas tout à fait au bord. On ne se bat pas avec le
prompt : **on recadre à 90 % au centre** à l'intégration (voir plus bas).
👉 Conséquence : **garder le sujet à ≥ 12 % des bords**, sinon le recadrage le
coupe. Constaté sur `decouverte_3` : la silhouette du bas s'est fait rogner.

**3. Sans « one single plain unbroken flat colour sky », le ciel se découpe**
en patchwork de blocs bleus — joli en grand, illisible en vignette.

---

## 🔵 LE SOCLE (à coller devant chaque sujet)

```
Hand-painted gouache illustration. Flat opaque shapes, visible brush texture,
matte finish, slightly uneven hand-cut edges.

FULL BLEED: the painted artwork fills the entire square frame completely, edge to
edge, corner to corner. The paint runs off all four edges. This is the artwork
itself, NOT a photograph of a painting.
Night scene. Deep ink-blue sky, small irregular white stars hand-placed at
uneven sizes and spacing.
Strictly limited palette, saturated and flat — ink blue #0E1733, night blue
#101B4A, electric blue #1C4FD8, violet #7B2FD1, cream #F5E3C8, warm dawn #E8A38C.
Large simple shapes and silhouettes. Generous empty sky. Naive, calm, quiet,
slightly imperfect. Flat composition, no perspective tricks.
Square 1:1.

Negative — do not include: teal, cyan, turquoise, neon, glow, bloom, halo,
lens flare, smooth digital gradient, 3D render, photorealism, vector art,
gloss, chrome, text, letters, logo, watermark, signature, UI elements,
human faces, hands, brand marks, busy detail, clutter,
white border, white margin, paper sheet, paper edge, torn edge, deckled edge,
frame, mockup, drop shadow, table surface, photograph of artwork, canvas edge,
vignette, patchwork of blue blocks, cloud shapes.
```

*(Variante crayon — remplacer les 2 premières lignes par :)*
```
Hand-drawn colored pencil illustration on textured paper. Visible directional
pencil strokes, layered saturated pigment, strong paper grain, no blending.
```

---

## 🎨 Les 7 scènes de catégorie
Une couleur dominante par catégorie — c'est ce qui remplace le tout-turquoise.

| # | Catégorie (app) | Couleur | Sujet à ajouter au socle |
|---|---|---|---|
| 1 | **Découverte de la méditation** | crème | `A single cream-coloured seated silhouette, abstract and rounded, centred low on a deep blue horizon. A large full cream moon high above in the starry sky. Symmetry, stillness.` |
| 2 | **Une minute pour toi** (express) | aube | `One small warm-lit window glowing dawn-orange in a vast dark blue night. Nothing else. Enormous empty starry sky above it.` |
| 3 | **Actualité & Surcharge mentale** | bleu électrique | `A wide calm electric-blue sea meeting a dark starry sky at a perfectly flat horizon. Empty. No boats, no land. Total silence.` |
| 4 | **Stress & Anxiété** | violet | `A large smooth violet hill filling the lower half, soft rounded summit, against a deep blue starry sky. Two simple dark curved brush strokes on the hill. One shooting star.` |
| 5 | **Sommeil** | crème + bleu | `A huge full cream moon low over a deep electric-blue sea, its reflection a single straight cream band on the water. Dark starry sky above.` |
| 6 | **Respiration** | bleu électrique | `Concentric painted rings opening outward from the centre, alternating electric blue and ink blue, hand-painted with uneven edges. A small cream circle at the very centre. Stars in the corners.` |
| 7 | **Émotions** | violet + aube | `Two large rounded hills side by side, one violet one warm dawn-orange, gently touching at the middle, under a deep blue starry sky.` |

---

## 🌙 Header de la Home
**Format 3:2 (2048×1365)**, zone du haut-gauche laissée VIDE pour la salutation.

```
[SOCLE, but aspect ratio 3:2 instead of square]
A wide night landscape: dark rolling hills along the bottom third, a large
cream moon on the RIGHT side, dense small white stars across the sky.
The entire LEFT and UPPER-LEFT area must stay empty deep blue sky — no
elements there. Faint violet aurora band low on the horizon.
```

---

## 🚪 Onboarding (4 écrans, format 3:4 portrait 1536×2048)
Une progression : nuit profonde → aube. C'est le récit de l'app.

1. `A single small cream figure standing alone at the bottom of a vast dark blue starry night. Overwhelming empty sky.`
2. `The same small cream figure, now seated, on a violet hill under the stars. Calmer, closer.`
3. `The seated cream figure with concentric painted rings radiating softly around it, electric blue on ink blue.`
4. `A thin warm dawn-orange band appearing at the horizon behind the seated figure. First light. Stars fading at the top.`

---

## 🎧 Les 33 covers de séances — méthode
**Ne PAS générer 33 images indépendantes** : ça produit une collection
disparate qui se voit immédiatement.

Méthode : **7 scènes-mères** (celles des catégories) × **variations contrôlées**.
Pour chaque séance, reprendre la scène-mère de sa catégorie et changer UNE
seule variable :

- l'heure : `just after sunset` / `deep night` / `before dawn`
- le cadrage : `zoomed in on the moon` / `wide shot` / `low horizon, huge sky`
- un élément unique : `one shooting star` / `two hills instead of one` /
  `the moon partly hidden`

Exemple pour `sleep_3` (« Rituel pré-sommeil ») :
```
[SOCLE]
A huge full cream moon low over a deep electric-blue sea, its reflection a
single straight cream band on the water. Dark starry sky above.
Variation: zoomed in, the moon fills the upper half, horizon very low,
before-dawn tones.
```

Liste complète des 33 séances : `lib/features/explore/data/explore_repository.dart`.

---

## 📐 Contraintes techniques (à respecter en sortie)

- **Format de livraison** : PNG 2048×2048 → je convertis en **WebP q82** à
  l'intégration (≈ 5× plus léger ; les 40 images actuelles pèsent déjà 3,4 Mo,
  et une image texturée pèse plus lourd qu'un dégradé).
- **Marge de sécurité** : garder le sujet à ≥ 12 % des bords — les vignettes
  sont recadrées en carré ET en 16:9 selon les écrans.
- **Zone de texte** : sur les covers, le tiers inférieur doit rester sombre et
  peu chargé (le titre de séance s'écrit dessus en blanc).
- **Nommage** : garder exactement les noms actuels
  (`sessions/sleep/sleep_1.png`, etc.) → intégration sans rien casser.
- **Pas d'alpha** : fond plein, pas de transparence.
- **Recadrage obligatoire** après génération, pour tuer le liseré de bord :

```bash
ffmpeg -y -i brut.png -vf "crop=iw*0.90:ih*0.90,scale=1024:1024" net.png
```

---

## ✅ Test de validation d'une image
Avant de valider une série, vérifier les 5 points :
1. On voit la **matière** (grain / pinceau) en zoomant ? Sinon → refusée.
2. Il y a **≤ 4 couleurs** franches ? Sinon → refusée.
3. Aucun **halo / dégradé lisse** ? Sinon → refusée.
4. Réduite à **120 px de large**, on lit encore la forme ? Sinon → refusée.
5. Posée à côté des 6 autres, on dirait **la même main** ? Sinon → refusée.


---

# ⭐ MÉTHODE VALIDÉE (25/08/2026, série Sommeil) — REMPLACE TOUT LE RESTE

Après 7 itérations sur la catégorie Sommeil, ce qui marche VRAIMENT :

1. **Ne jamais décrire le style en texte seul.** Donner à Gemini les
   **3 images Découverte comme références d'images** dans la requête
   (`assets/images/sessions/decouverte/decouverte_{1,2,3}.png`) avec la
   consigne « copy this painting style exactly ». Script :
   scratchpad `gen_ref.py` (multimodal, inlineData + texte).
2. **Un sujet = le titre de la séance, version littérale et minimale.**
   Pas d'abstraction. Exemples validés : « Détente du soir » = visage
   violet allongé qui souffle des feuilles ; « Visualisation apaisante » =
   un œil avec étoiles dans l'iris ; « Entre deux mondes » = dormeur +
   âme reliée par un fil.
3. **Palette : max 4 couleurs par image** (encre, bleu électrique, violet,
   crème). Les versions « lumineuses/texturées » ont été REJETÉES : trop
   précises, trop de lumière. Le plat naïf gagne.
4. **Toujours interdire** : heart shape, extra figures, white border, photo
   of painting. Gemini adore ajouter des cœurs et des mini-personnages.
5. **Post-traitement** : crop 90 % centre (liseré de bord), 800×800,
   **cwebp -q 82** → ~20 Ko/image (PNG texturé = 600 Ko, inacceptable).
   Penser à mettre à jour les chemins .png → .webp dans
   `explore_repository.dart`.
6. Prix réel constaté : ~0,13 $/image, ~2 s de génération, itérations
   comprises ≈ 1 $/catégorie.

### Piège n°7 (26/08, série des 27) : les références déteignent
Gemini recopie des ÉLÉMENTS des images de référence dans la nouvelle image :
le petit méditant de decouverte_1 est apparu en bas de 7 images sur 27, le
grand dôme blanc de decouverte_3 en haut de 3. Parades : interdire
explicitement « any person or object not described in the scene », « any
large pale dome or arc », et en secours recadrer tronqué en bas
(`crop=iw*0.90:ih*0.86:(iw-ow)/2:ih*0.02`).
