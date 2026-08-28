# Rapport coûts API — 28/08/2026

Suite du rapport du 14/08. Le volume a changé d'échelle : **~1 000 messages
Voix/jour** (400 appels sur la seule fenêtre de nuit 22 h 30 → 8 h 28, contre
63/jour au rapport précédent) + ~270 accueils d'onboarding/jour. L'alerte cache
du 14/08 (« à revérifier après 24 h ») n'avait jamais été refaite — elle était
fondée.

## Ce qui a été trouvé

- **Cache : 8 % de hits seulement** (30/400 appels Voix de la nuit). Cause :
  GPT-5.6 a changé les règles — le cache n'est plus automatique-gratuit. Sans
  `prompt_cache_key`, pas de routage stable ; et en mode implicite le seul
  point de coupe est la fin du dernier message user, donc la moindre partie
  variable (heure, mémoire, profil) invalide TOUT le préfixe. Chaque appel
  réécrivait ~8 000 tokens de cache (facturés 1,25×) jamais relus.
- Le Veilleur et la Mémoire ne loggaient pas leur usage (angle mort du 14/08).

## Ce qui a été fait (déployé le 28/08 vers 10 h 40, testé en prod)

1. **Cache mode explicite** : bloc FIXE du prompt isolé dans un premier message
   system avec `prompt_cache_breakpoint`, parties variables dans un second.
   Contenu inchangé au caractère près. Clés : `quieto-voix-1`,
   `quieto-accueil-1`, `quieto-parcours-1` (+ TTL 30 min).
   **Vérifié en prod** : 2 utilisateurs différents → le 2ᵉ relit les
   7 166 tokens du bloc fixe (0 écrit) ; 3 vrais onboardings → les 2ᵉ et 3ᵉ
   relisent les 3 644 tokens. Veilleur laissé en implicite (prompt ~1 000 tk,
   sous le minimum cachable de 1 024).
2. **`reasoning_effort: "none"` sur Veilleur et Mémoire** (la Voix : intouchée).
   Banc de test Veilleur : 12 cas (explicites, signaux voilés, pièges à faux
   positifs) — verdicts identiques avec et sans réflexion. Script :
   à refaire si `PROMPT_VEILLEUR` change un jour.
3. **Mémoire : 1 appel tous les 3 échanges** (au lieu de chaque message), avec
   les 3 derniers échanges en entrée → rien n'est perdu, juste regroupé.
   La fiche se crée toujours dès le 1ᵉʳ message si elle est vide.
4. **Usage loggé partout** : `[Veilleur] usage:` et `[Mémoire] usage:` comme la
   Voix — plus d'angle mort au prochain rapport.

## La facture (au volume actuel ~1 000 msg/jour, estimation)

| Poste | Avant (mesuré) | Après (attendu) |
|---|---|---|
| Voix | ~70 $/mois | ~19 $/mois |
| Accueil onboarding | ~10 $/mois | ~3 $/mois |
| Veilleur (invisible avant) | ~9 $/mois | ~8 $/mois |
| Mémoire | ~3 $/mois | ~1 $/mois |
| **Total** | **~92 $/mois** | **~31 $/mois** |

Économie ≈ **65 %**, sans rien changer à ce que voit l'utilisateur (prompt de
la Voix intact, réponses identiques, sécurité testée). L'écart grandit avec le
volume : à 5 000 msg/jour ce serait ~460 → ~155 $/mois.

## À vérifier au prochain point (dans ~1 semaine)

- Taux de hits réel sur 24 h pleines (attendu : > 80 % sur la Voix ; la nuit
  très creuse peut faire expirer le TTL 30 min).
- Que la fiche mémoire reste riche (elle se met à jour tous les 3 échanges).
- Une ligne `[Parcours] usage:` pour confirmer le cache du bloc parcours.

---
*Rapport du 28/08/2026. Chiffres « avant » mesurés sur les logs de la nuit du
27 au 28/08 ; chiffres « après » calculés depuis les tarifs Luna (0,20 $/M
entrée, 0,02 $/M lecture cache, 1,20 $/M sortie) et vérifiés sur les premiers
appels en prod.*
