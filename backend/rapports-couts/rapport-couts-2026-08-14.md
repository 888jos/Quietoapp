# Rapport coûts API — 14/08/2026

Premier rapport après la bascule de la Voix sur **gpt-5.6-luna** (OpenAI, commit 9c335ff, déployée ce matin ~9 h 45).

**Sources** : logs Cloud Functions (`firebase functions:log --project quieto-06 -n 5000`, fenêtre du 11/08 18 h 17 au 14/08 9 h 46, 285 lignes `usage:`), grille OpenAI ([developers.openai.com](https://developers.openai.com/api/docs/models/gpt-5.6-luna)), grille Anthropic (tarif de lancement Sonnet 5 jusqu'au 31/08). Montants en dollars (les API facturent en $ ; à ces ordres de grandeur la conversion en € ne change rien à la lecture).

> Nota : le JOURNAL-QUIETO du 14/08 chiffre sur un échantillon plus large (1 130 messages) et sur TOUT le backend (Voix + Veilleur + Mémoire + Parcours) : ~70 $/mois avant → ~15 $ attendus (~8 $ si le cache prend). Ce rapport ne mesure que la Voix, sur la fenêtre de logs du 11-14/08 — les deux sont cohérents, le périmètre diffère.

## La facture

- **Avant la bascule (Sonnet 5)** : ~63 messages Voix/jour (moyenne des 2 jours pleins), ~1,07 ¢/message → **~20 $/mois** ; le même usage serait passé à **~30 $/mois après le 31/08** (fin du tarif de lancement).
- **Après la bascule (Luna)** : **~2 $/mois** si le cache fonctionne, ~5,50 $/mois s'il ne prend jamais (voir alerte). Soit une division par **~10** (pas ~25× comme l'annonçait le message de commit — les vrais tarifs Luna sont 0,20 $/1,20 $ par M, pas 0,10 $/0,60 $).

## Coûts unitaires

| Quoi | Sonnet 5 (avant) | Luna cache OK | Luna cache KO |
|---|---|---|---|
| 1 message Voix | 1,07 ¢ | **0,10 ¢** | 0,28 ¢ |
| Utilisateur moyen (~10 msg/j) | ~3,20 $/mois | ~0,30 $/mois | ~0,84 $/mois |
| Gros utilisateur (50 msg/j) | ~16 $/mois | ~1,50 $/mois | ~4,20 $/mois |

Profil moyen d'un message (281 appels ère Sonnet) : 2 691 tokens plein tarif + 7 169 lus en cache + 267 de sortie (dont ~55 de réflexion).

**Marge par abonné** : 89 €/an (≈ 6,30 €/mois net après commission Apple 15 %) ou 16,90 €/mois (≈ 14,35 € net). Même un abonné très bavard (50 msg/j) coûte ~1,50-4 $/mois en IA → **aucun abonné ne peut te coûter plus qu'il ne rapporte**. Un utilisateur gratuit (quota découverte) coûte quelques dixièmes de centime au total : négligeable.

**Non mesurés** : les appels Veilleur et Mémoire ne loggent pas leur usage — estimation depuis le code (ère Haiku) : ~0,2-0,4 ¢/message à deux, soit potentiellement **plus cher que la Voix elle-même** ; leur passage sur Luna à midi (commit 667df18) divise leur coût d'entrée par ~5. Aucune génération de parcours (`[Parcours]`) dans la fenêtre de logs ; les prochaines seront sur Luna, au format OpenAI.

## 🟠 ALERTE à vérifier demain : le cache Luna ne prend pas

Sur les 3 premiers appels Luna (9 h 44-9 h 46), `cached_tokens = 0` partout — y compris deux appels à 15 s d'écart qui partagent le même préfixe système. Chaque appel **réécrit** tout le prompt en cache (18 581 tokens écrits, facturés 1,25× l'entrée, 0 relu) : ~99 % du coût de la matinée est parti en écritures de cache jamais lues.

- Échantillon minuscule (1ʳᵉ heure après déploiement) : peut être un simple délai de propagation du cache OpenAI.
- **À refaire après 24 h de trafic** : si `cached_tokens` reste à 0, chercher un octet variable qui a fui en tête du prompt système (le cache OpenAI est automatique sur le préfixe, ≥ 1 024 tokens identiques).
- Enjeu : facture Voix ×2,8 (5,50 $ au lieu de 2 $/mois). Pas dramatique, mais c'est le principal levier restant.

## Économies possibles (classées par gain)

1. **~3,50 $/mois — faire prendre le cache Luna** (voir alerte) : 🟢 gratuit, aucun impact utilisateur.
2. **~1-2 $/mois — Veilleur + Mémoire** : la bascule intégrale vers Luna (commit 667df18, déployée et testée en prod à 12 h 31) les rend déjà ~5× moins chers en entrée. 🟢. Reste à **faire logger leur usage** comme la Voix (un `console.log` chacun), sinon ils resteront invisibles au prochain rapport.
3. Rien d'autre de significatif : à ~2 $/mois de facture Voix, chaque heure passée à optimiser coûte plus que ce qu'elle rapporte.

## Déjà bien optimisé — ne pas y retoucher

- Le cache Anthropic prenait à 86-100 % : la séparation bloc fixe/variable du prompt est saine, elle a été conservée pour Luna.
- La fenêtre glissante `FENETRE_VOIX = 8` plafonne bien le coût par message.
- La Plume (2ᵉ appel par message) a été supprimée le 14/08 : un appel de moins par message.
- La sortie moyenne (267 tokens) est courte — pas de gras côté réponses.

---
*Rapport généré le 14/08/2026 à la mi-journée, mis à jour après le commit 667df18 (bascule intégrale sur Luna, déployée à 12 h 31). Prochain point : vérifier `cached_tokens` après 24 h de trafic Luna, et chiffrer une génération de parcours Luna dès qu'une ligne `[Parcours]` apparaît.*
