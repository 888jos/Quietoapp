# quieto-backend — Cloud Functions de Quieto

> Créé le 12/08/2026. Backend Firebase (projet `quieto-06`) de l'app Quieto (`~/dev/QuietoApp`).
> Node 24 · `firebase-functions` v7 · SDK `@anthropic-ai/sdk`. Tout le code vit dans `functions/index.js`.

## Les 4 fonctions déployées

| Fonction | Type | Rôle |
|---|---|---|
| `louane` | `onCall` | Fait parler Louane. **La Voix** (`claude-sonnet-5`) répond ; **le Veilleur** (sécurité, Haiku) tourne **en parallèle** sur chaque message et renvoie un signal (jamais de texte à la personne — le message de sécurité niveau 2 est écrit en dur, avec le 3114 et le 15) ; **la Plume** (Haiku) polit le français sans changer le sens ; **la Mémoire** (Haiku) met à jour la fiche mémoire de la personne. Stateless : l'app renvoie historique + fiche + état du parcours à chaque appel. |
| `genererParcours` | `onCall` | Crée le **programme 7 jours** à partir de la conversation (historique + fiche + profil) : une séance du catalogue par jour + un mot de Louane. Le jour 1 est **toujours gratuit** (la conversion se joue sur la suite). Stateless : l'app persiste le programme reçu. |
| `trace` | `onCall` | **La Vigie** (analytics maison) : l'app envoie ses événements par lots (~20), une ligne par événement dans Firestore `vigie_events`. 100 % anonyme (ID d'installation aléatoire, jamais de prénom ni de texte). |
| `revenuecat` | `onRequest` | **Webhook RevenueCat** (déployé le 11/08/2026) : l'issue des essais (conversion, expiration, annulation…) arrive même des jours après, app fermée — rangée dans `vigie_events` avec l'ID Vigie (étiquette `vigie` posée par l'app via `setAttributes`). |

Modèles : Voix = `claude-sonnet-5` · Veilleur / Plume / Mémoire = `claude-haiku-4-5-20251001` (non cachables, prompts < 4 096 tokens). Cache Anthropic de la Voix : `ttl: "1h"`. Fenêtre d'historique de la Voix : 8 messages (`FENETRE_VOIX`), Veilleur : 6.

## Points d'architecture à connaître

- **Le prompt de la Voix vit dans `index.js`** (`PROMPT_VOIX`) — si on le retravaille ailleurs, le recopier ici.
- **Bibliothécaire intégré à la Voix** (pas d'agent séparé — un 2ᵉ agent casse le personnage) : Louane connaît le catalogue via `functions/catalogue_seances.json` — ⚠️ à garder **synchro avec l'app** (`lib/features/explore/data/explore_repository.dart`).
- **Marqueurs en fin de message** : `[PARCOURS]` (strippé côté serveur → signal `parcoursPropose`, l'app en fait un bouton) ; même mécanique pour lancer une séance depuis la conversation.
- **Firestore = deny-all** (`firestore.rules`) : l'app n'écrit jamais directement, tout passe par les fonctions. Collections : `vigie_events` (événements + webhook RC), `vigie_louane` (une ligne par message Louane, compteurs seulement).
- **Secrets** via `defineSecret` : `ANTHROPIC_KEY`, `RC_WEBHOOK_SECRET`. Jamais dans le code ni dans l'app.
- La Mémoire et la Plume ne doivent **jamais casser la requête** : en cas d'erreur elles rendent la main (fiche inchangée / texte non poli).

## Commandes utiles

```bash
firebase deploy --only functions --project quieto-06   # déployer
firebase functions:log --project quieto-06             # logs de prod
```

## État au 12/08/2026

- Dernier commit : `99667b6` — prompt Voix retravaillé + réduction coûts (historique 16 → 8, réponses courtes par défaut).
- ⚠️ D'après le journal de bord, ce commit **et** le cache TTL 1 h (`b4be22e`) ne sont **pas encore déployés** en prod — un `firebase deploy --only functions` embarquera les deux (à vérifier par Paul).
- ⚠️ 31/08/2026 : fin du tarif de lancement Sonnet 5 → facture de la Voix +50 %.
- Journal de bord du projet : `~/dev/JOURNAL-QUIETO.md`.
