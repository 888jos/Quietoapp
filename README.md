# quieto-backend — Cloud Functions de Quieto

> Créé le 12/08/2026, remis à jour le 28/08/2026. Backend Firebase (projet `quieto-06`) de l'app Quieto (`~/dev/QuietoApp`).
> Node 24 · `firebase-functions` v7 · SDK `openai` (⚠️ plus aucun appel Anthropic depuis le 14/08/2026). Tout le code vit dans `functions/index.js`.

## Les 5 fonctions déployées

| Fonction | Type | Rôle |
|---|---|---|
| `louane` | `onCall` | Fait parler Louane. **La Voix** répond ; **le Veilleur** (sécurité) tourne **en parallèle** sur chaque message et renvoie un signal (jamais de texte à la personne — le message de sécurité niveau 2 est écrit en dur, avec le 3114 et le 15) ; **la Mémoire** met à jour la fiche mémoire de la personne (1 échange sur 3 depuis le 28/08, avec les 3 derniers échanges en entrée). Stateless : l'app renvoie historique + fiche + état du parcours à chaque appel. (La **Plume** a été supprimée le 14/08/2026 ; la **Boussole** — classification des sujets pour la Vigie — est écrite mais **désactivée**, sortie des `Promise.all`.) |
| `genererParcours` | `onCall` | Crée le **programme 7 jours** à partir de la conversation (historique + fiche + profil) : une séance du catalogue par jour + un mot de Louane. Le jour 1 est **toujours gratuit** (la conversion se joue sur la suite). Depuis le 26/08 (`39853fd`) : si l'app envoie `premierParcours: true` (1.0.20+, personne qui n'a jamais terminé de séance), le verrou déterministe `forcerPremiereMeditation` place « Ma première méditation » en jour 1. Stateless : l'app persiste le programme reçu. |
| `accueilOnboarding` | `onCall` | Ajoutée le 15/08/2026 (`e84391a`). Écrit les 2 bulles d'accueil de l'écran de **compréhension** en fin d'onboarding (Louane redit ce qu'elle a compris des réponses au questionnaire). L'app a un repli local si le serveur traîne (> 4 s) ou tombe. |
| `trace` | `onCall` | **La Vigie** (analytics maison) : l'app envoie ses événements par lots (~20), une ligne par événement dans Firestore `vigie_events`. 100 % anonyme (ID d'installation aléatoire, jamais de prénom ni de texte). Depuis le 17/08 (`34de2ad`) : range aussi la plateforme `os` (ios/android, liste blanche) envoyée par l'app 1.0.18+. |
| `revenuecat` | `onRequest` | **Webhook RevenueCat** (déployé le 11/08/2026) : l'issue des essais (conversion, expiration, annulation…) arrive même des jours après, app fermée — rangée dans `vigie_events` avec l'ID Vigie (étiquette `vigie` posée par l'app via `setAttributes`). |

Modèles : **tout sur `gpt-5.6-luna` (OpenAI)** depuis le 14/08/2026 — Voix, Veilleur, Mémoire, `genererParcours`, `accueilOnboarding`. Fenêtre d'historique de la Voix : 8 messages (`FENETRE_VOIX`), Veilleur : 6. ⚠️ Depuis le 28/08 (`10f36a1`, déployé), le cache OpenAI n'est **plus automatique** (les règles ont changé, il ne prenait qu'à 8 %) : il est **explicite** — `prompt_cache_key` par fonction (`quieto-voix-1`, `quieto-veilleur-1`, `quieto-parcours-1`), `prompt_cache_breakpoint` en fin de bloc system FIXE (prompt coupé en deux messages system, inchangé au caractère près), TTL 30 min. Aussi : `reasoning_effort: "none"` sur Veilleur (banc de 12 cas sensibles : verdicts identiques) et Mémoire, et la **Mémoire ne tourne plus qu'1 échange sur 3** (`nbEchangesAvant % 3 === 2`, avec les 3 derniers échanges en entrée — rien de perdu), usage loggé partout.

## Points d'architecture à connaître

- **Le prompt de la Voix vit dans `index.js`** (`PROMPT_VOIX`) — si on le retravaille ailleurs, le recopier ici. Depuis le 26/08 (`44ad80f`, déployé) : bloc « QUI TU ES, ET RIEN D'AUTRE » — Louane ne reprend jamais les mots IA/robot/ChatGPT, même pour blaguer.
- **Bibliothécaire intégré à la Voix** (pas d'agent séparé — un 2ᵉ agent casse le personnage) : Louane connaît le catalogue via `functions/catalogue_seances.json` — ⚠️ à garder **synchro avec l'app** (`lib/features/explore/data/explore_repository.dart`).
- **Marqueurs en fin de message** : `[PARCOURS]` (strippé côté serveur → signal `parcoursPropose`, l'app en fait un bouton) ; même mécanique pour lancer une séance depuis la conversation. `[BULLE]` découpe la réponse en 2-4 petites bulles (le serveur renvoie le tableau `bulles` + `reponse` d'un bloc pour les vieilles apps ; filet serveur : une réponse courte à sauts de paragraphe est découpée même sans marqueur).
- **Firestore = deny-all** (`firestore.rules`) : l'app n'écrit jamais directement, tout passe par les fonctions. Collections : `vigie_events` (événements + webhook RC), `vigie_louane` (une ligne par message Louane, compteurs seulement — `nbBulles`, `avecSante` depuis le 15/08).
- **Secrets** via `defineSecret` : `OPENAI_KEY`, `RC_WEBHOOK_SECRET`. Jamais dans le code ni dans l'app. (`ANTHROPIC_KEY` ne sert plus — le secret traîne encore dans Secret Manager, inoffensif, révocable.)
- La Mémoire ne doit **jamais casser la requête** : en cas d'erreur elle rend la main (fiche inchangée). Même règle pour le Veilleur (échec = pas de signal, jamais d'erreur remontée).

## Commandes utiles

```bash
firebase deploy --only functions --project quieto-06   # déployer
firebase functions:log --project quieto-06             # logs de prod
```

## État au 28/08/2026

- Dernier commit : `10f36a1` — **coûts API ÷~3** (cache explicite + Veilleur/Mémoire sans réflexion + Mémoire 1/3), **déployé et vérifié en prod le 28/08** : cache relu entre utilisateurs différents (7 166 tk Voix, 3 644 tk Accueil sur de vrais onboardings). À ~1 000 msg Louane/jour : **~92 → ~31 $/mois attendus**. Détail : `rapports-couts/rapport-couts-2026-08-28.md` (hors git). À revérifier dans ~1 semaine : taux de hits sur 24 h, richesse des fiches mémoire.
- Avant lui : `44ad80f` — identité de Louane verrouillée (jamais de sujet IA/robot), déployé et testé en prod le 26/08 avec `39853fd` (première méditation forcée — inerte pour les apps ≤ 1.0.19, actif à partir de la 1.0.20).
- Coûts (mesure du 14/08) : Voix ~0,27 ¢/message au tarif Luna officiel (0,20 $/1,20 $ le M). ⚠️ Vérifier qu'un **plafond de dépense** est posé sur le compte OpenAI.
- Retour arrière vers Anthropic si besoin : redéployer `2ce30bb` (dernier commit 100 % Claude).
- Journal de bord du projet : `~/dev/JOURNAL-QUIETO.md`.
