# Direction artistique Quieto — audit + parti pris

> Écrit le 25/08/2026. Objectif : tuer le look « fait par une IA ».
> Références données par Paul : 3 illustrations nocturnes (crayon de couleur /
> gouache), matière visible, palette réduite mais franche, formes simples.

---

## 1. Ce qui fait « IA » aujourd'hui — par ordre de gravité

### 🔴 1. Les 40 images de séances (le coupable n°1)
`assets/images/sessions/**` — dégradés lisses, halos turquoise, formes
vectorielles molles. `sleep_1.png` = lune turquoise avec glow. `stress_1.png`
= nœud lumineux flottant. **Zéro matière, zéro trace de main.**
C'est exactement le cliché « image générée ». Rien à sauver, tout à refaire.

### 🔴 2. Une seule couleur d'accent, partout
**172 usages de `AppColors.accent` (#5CE0D8)** dans `lib/`. Icônes, chevrons,
durées, bordures gauches, sliders, halos, badges, glyphes : tout est turquoise.
Une app entière sur une seule teinte = signature template Figma.
Les 3 références de Paul ont **3-4 couleurs franches** par image.

### 🔴 3. Les images ne sont presque jamais montrées
33 covers en assets, visibles **uniquement** dans le player, l'écran de
lancement, la carte Louane et le header de catégorie.
La **Home** et la **liste des séances** sont 100 % texte sur cards bleues.
→ C'est aussi un problème business : la fuite home → 1re séance (12 %) vient
en partie de là. Une liste de cards texte ne donne pas envie de cliquer.

### 🟠 4. Glyphes dessinés en code
`lib/core/ui/category_glyph.dart` — 7 formes (éclair, journal, cœur, lune,
spirale, nœud, silhouette assise), **toutes turquoise + `MaskFilter.blur`**.
Iconographie de banque d'icônes, uniformisée par la couleur.

### 🟠 5. Emojis dans l'UI produit
Catalogue : 🧘 ⚡ 📰 😤 🌙 🌬️ 💛 (`explore_repository.dart`)
Profil : ✉️ 📄 📋 🔐 🌧️ 👋 (`profile_page.dart`)
Home : `emoji: '🧘'` en dur (`home_page.dart:136`).
Rien ne dit « pas designé » comme un emoji dans une interface payante.

### 🟠 6. Toutes les cards sont le même bloc
Même `cardSurface` #0D2137, même radius, même padding 16, même bordure gauche
turquoise 3-4 px (pattern « callout » de doc web).
`category_list_card.dart`, `session_card.dart`, `featured_session_card.dart`,
profil : le même rectangle répété d'écran en écran.
Bonus fragile : `category_list_card.dart` positionne le badge avec un
`Transform.translate(Offset(70, -28))` + `Transform.scale(1.125)` en dur.

### 🟡 7. Typographie par défaut
`app_text_styles.dart` déclare `fontFamily: 'SF Pro Display'` — **police non
embarquée** (pubspec ne contient que HankenGrotesk et CormorantGaramond) →
fallback système. Tailles 32/22/17/16/14/12, poids w700/w600, letterSpacing 0.
C'est la grille Material sortie de la boîte.
Cormorant n'est utilisée **que** pour la salutation de la Home ; Hanken que
pour le paywall. Deux belles polices achetées, presque pas servies.

### 🟡 8. Espacements et rayons parfaitement réguliers
4 / 8 / 16 / 24 / 32 / 48 et radius 8 / 12 / 20 / 28. Tout au multiple de 8,
appliqué uniformément. Résultat : rythme plat, aucun écran n'a de silhouette
propre. Un design fait main a des respirations volontairement inégales.

### 🟡 9. Deux familles d'icônes mélangées
`Icons.*` Material (18 usages) + `Iconsax.*` (12). Deux grammaires visuelles
dans la même app.

### 🟡 10. Player générique
`player_page.dart` — cover carré 220×220 avec bordure turquoise 2 px, titre
centré, slider Material, 3 boutons ronds centrés. C'est le player Spotify.
Pour une app de méditation, l'image devrait occuper l'écran et les contrôles
s'effacer.

---

## 2. Le parti pris (ce qu'on vise)

**Une nuit peinte à la main.** Matière visible, aplats francs, formes grandes
et simples, beaucoup de ciel vide. Pas de lueur, pas de dégradé, pas de néon.

### Palette (remplace le turquoise unique)
| Rôle | Hex | Usage |
|---|---|---|
| Encre (fond) | `#0E1733` | fond de l'app, ciel profond |
| Bleu nuit | `#101B4A` | surfaces, ciels |
| Bleu électrique | `#1C4FD8` | mer, aplats vifs, accent 1 |
| Violet | `#7B2FD1` | collines, accent 2 |
| Crème | `#F5E3C8` | lune, silhouettes, **texte de titre** |
| Aube | `#E8A38C` | horizon, accent chaud rare |
| Blanc étoile | `#FFFFFF` | étoiles, texte courant |

Le turquoise ne disparaît pas d'un coup : il se réduit à un usage rare
(état actif du lecteur) ou saute complètement selon le rendu des images.

### Règles
1. **Une image par séance, visible dès la liste.** Les cards deviennent des
   vignettes illustrées, pas des rectangles de texte.
2. **Zéro emoji, zéro glyphe turquoise.** Remplacés par l'illustration.
3. **Cormorant Garamond pour tous les titres**, Hanken Grotesk pour le corps.
   Deux polices, deux rôles nets. Suppression de `SF Pro Display`.
4. **Le player passe en plein écran** : l'illustration monte en fond, les
   contrôles flottent en bas sur un voile sombre.
5. **Chaque catégorie a sa couleur** tirée de la palette. Fini le tout-turquoise.
6. **Rythme irrégulier assumé** : le header respire large, les listes serrent.

### Ce qu'on ne touche pas
- **Le paywall** (`paywall_screen.dart` / `paywall_page.dart`) : design Sereine
  validé, il convertit. On n'y touche pas.
- La logique métier, l'audio, la Vigie, RevenueCat.

---

## 3. Répartition du travail
- **Images** → générées ailleurs (Midjourney / Nano Banana / autre) à partir de
  `PROMPTS-VISUELS.md`.
- **Intégration + refonte des écrans** → en code ici.

## 4. Ordre d'exécution recommandé
1. Générer **3 images test** (sommeil, stress, respiration) → valider le style.
2. Générer les **7 scènes de catégorie**.
3. Intégrer : palette + typo + cards illustrées sur la **Home** (là où ça fuit).
4. Player plein écran.
5. Étendre aux 33 covers de séances.
6. Onboarding.

## État au 26/08/2026 (Scribe)
- ✅ Étapes 1, 2, 3 et 5 **faites et commitées** (`c8e3ba5`, `eb30399`, `37a9771`, part avec la 1.0.20) : les **35 covers** de séances en gouache (WebP), les **7 bandeaux de catégorie** (`assets/images/categories/`, 1400×788), cards illustrées sur la Home. Le générateur retenu : **API Gemini** (pas Midjourney) — méthode et pièges dans `PROMPTS-VISUELS.md`.
- Reste (éventuel, annoncé au journal) : onboarding + header Home, même méthode. Le point n°1 de l'audit (« 40 images, tout à refaire ») décrit l'état du 25/08 — il est réglé.
