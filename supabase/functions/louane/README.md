# Edge Function `louane`

Louane pour l'app iOS native (`app/ios/QuietoNative`), sans Firebase. Elle remplace
`louane-proxy`, qui se contentait de vérifier l'abonnement puis relayait vers la callable
Firebase `louane` (`backend/functions/index.js`). La fonction Firebase reste en ligne pour
l'app Flutter de production jusqu'à la sortie de l'app native : ne pas la modifier d'ici.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `index.ts` | Handler HTTP : JWT, `user_has_premium`, quotas, Voix ∥ Veilleur, 3114, Mémoire ∥ Juge, réponse |
| `prompts.ts` | Prompts et consignes, copiés de `index.js` (écarts listés plus bas) |
| `logic.ts` | Logique pure : bornes, fenêtre glissante, filet lexical, bulles et leurs filets, `[SEANCE:id]` |
| `openai.ts` | Chat Completions par `fetch` (modèle `gpt-5.6-luna`, mêmes paramètres que Firebase) |
| `store.ts` | Compteurs, quotas, mémoire d'alerte 3114 et stats dans Postgres |
| `catalogue.json` | Catalogue natif (94 séances), généré depuis `SessionCatalog.swift` |
| `logic_test.ts` | Tests des fonctions pures et du prompt construit depuis le catalogue |

Migration : `supabase/migrations/20261007090000_louane_supabase.sql`.

## Secrets et déploiement

`SUPABASE_URL` et `SUPABASE_SECRET_KEY` servent déjà aux autres fonctions. À ajouter :

```sh
supabase secrets set OPENAI_API_KEY=...        # même compte OpenAI que le secret Firebase OPENAI_KEY
supabase db push                               # applique 20261007090000_louane_supabase.sql
supabase functions deploy louane
# Quand la version native qui appelle `louane` est sortie :
supabase functions delete louane-proxy
supabase secrets unset QUIETO_FIREBASE_PROXY_SECRET QUIETO_LOUANE_FIREBASE_URL
```

La vérification du JWT reste active (pas d'entrée dans `config.toml`). Sans
`OPENAI_API_KEY` ou sans la clé Supabase, la fonction répond `503 not_configured`.

Tests (fonctions pures, sans réseau) :

```sh
deno test supabase/functions/louane/logic_test.ts
deno check supabase/functions/louane/index.ts
```

Régénérer `catalogue.json` à chaque changement de `SessionCatalog.swift` ou de
`Resources/Narration/narration-fr.json` : une entrée par `make(...)` / `breath(...)` avec
`id`, `titre`, `but` (l'intention), `duree_min` (la durée affichée par l'app : durée de la
narration arrondie, sinon les minutes déclarées), `categorie` (le cas de `QuietoCategory`),
`objectif` (le libellé de `QuietoGoal`) et `type` (`meditation` / `respiration`).

## Contrat (inchangé pour l'app)

`POST /functions/v1/louane`, `Authorization: Bearer <jeton Supabase>`, corps
`{"data": {message, historique, heure, jour, accueil, prenom, memoire, profil, parcours,
ecoutes, santeDispo, vigie, session}}` (32 Ko max). Réponse `{"result": {...}}` avec
`reponse`, `bulles`, `securite`, `niveau`, `memoire`, `seance` ({id, titre, duree_min,
categorie, premium} ou null), et `paywall` / `plafond` quand la Voix n'a pas tourné.
Les erreurs gardent la forme des callables `{"error": {status, message}}` : 400
`INVALID_ARGUMENT`, 429 `RESOURCE_EXHAUSTED`, 500 `INTERNAL` ; plus 401, 413, 503 comme
`louane-proxy`.

## Porté à l'identique

- Prompts de la Voix, du Veilleur, de la Mémoire et du Juge, message de sécurité 3114
  validé, consignes d'heure, de jour, d'accueil, de mémoire, de profil, d'écoutes et de
  quota, consigne de lancement de séance (`[SEANCE:id]`, validé contre le catalogue,
  jamais sur un message de niveau 2).
- Sécurité : Voix et Veilleur en parallèle ; niveaux 0/1/2 ; niveau 2 → message 3114 au
  plus une fois par 24 h et par compte ; Veilleur illisible ou en panne → filet lexical
  (français + anglais) ; Voix en panne sur un message de niveau 2 → message 3114 au lieu
  d'une erreur ; le Veilleur tourne même au-delà du paywall et du plafond du jour.
- Bulles : `[BULLE]`, découpe sur les paragraphes, une phrase par bulle, 5 bulles max,
  une seule question, rien après « tu me testes », ni tiret long, ni emoji, ni écriture
  étrangère, ni prénom final, ni point final.
- Fiche mémoire un échange sur trois (ou tout de suite si vide) et Juge à la même cadence,
  avec leurs prompts, délais (12 s, sans réessai) et replis.
- Quotas : 300 appels Louane par jour et par IP hachée, 100 messages répondus par jour de
  Paris et par abonné (`plafond`), mur dur sans abonnement (`paywall`), comme le chemin
  ponté de Firebase pour l'app native.
- OpenAI : même modèle, `max_completion_tokens`, `reasoning_effort`, `response_format`,
  `prompt_cache_key` et point de coupe explicite du cache ; délai 20 s, un réessai.
- Bornes sur chaque champ reçu et fenêtres glissantes (8 tours Voix, 3 tours Veilleur).

L'équivalence a été vérifiée en exécutant les fonctions d'origine de `index.js` à côté du
portage sur les mêmes entrées (toutes les consignes, la chaîne des bulles, le filet
lexical, la détection de plaintes, le nettoyage des entrées) : sorties identiques.

## Ajouts de l'app native (07/10/2026)

- **Sons d'ambiance** : `catalogue.json` liste aussi les `sons` inclus dans l'app
  (`QuietoAmbience`, seulement ceux dont le fichier est dans `Resources/Ambiences`).
  Marqueur `[SON:id]`, validé contre cette liste, jamais au niveau 2 ; réponse
  `son: {id, titre, raison}` ou `null`. Une méditation peut avoir un son en fond
  (`[SEANCE:id] [SON:id]`), jamais un exercice de respiration.
- **Phrase de la carte** : `[POURQUOI:…]` après le marqueur, nettoyée et bornée à
  90 caractères, renvoyée dans `seance.raison` (ou `son.raison` pour un son seul).
- **Guide des besoins** (`CONSIGNE_GUIDE_BESOINS`) : quelle pratique pour quel état
  (panique → soupir, sommeil → 4-7-8, rumination → ancrage…), ids vérifiés par les tests.
- **Langue** : `langue` (code de l'app) → `consigneLangue` ; le filtre « écriture
  étrangère » laisse passer le japonais, le coréen et le chinois quand c'est la langue
  de l'app. Le message de sécurité 3114 reste en français.
- **Programme** : `parcours.prochaine` (id validé) → Louane sait quelle est la séance
  du jour et la lance si on la lui demande.
- `prompt_cache_key` passe à `quieto-voix-2` (le bloc fixe a changé).

Régénérer `sons` quand un son est ajouté à `Resources/Ambiences`.

## Écarts volontaires

- **Identité** : JWT Supabase (`auth.getUser`) et `user_has_premium`, comme
  `louane-proxy`. Compteurs et mémoire d'alerte sont rangés sous l'id Supabase, pas sous le
  `firebase_uid` hérité : les compteurs Firestore ne sont pas migrés, l'ancienne clé
  n'apporterait rien, et une clé qui référence `profiles` s'efface avec le compte
  (`on delete cascade`). Sans abonnement, la réponse est `200` avec `paywall: true` (après
  le Veilleur) au lieu du `402` du proxy ; l'app traite les deux de la même façon.
- **Pas de programme créé par Louane** : l'app native construit son programme elle-même
  (onglet Programme). `CONSIGNE_PARCOURS_OFFRE` est remplacée par
  `CONSIGNE_PROGRAMME_NATIF` (ne jamais proposer ni promettre de programme, renvoyer vers
  l'onglet Programme si elle en demande un) ; deux phrases du prompt de la Voix qui
  menaient au programme mènent à une séance ; `consigneCreuser` n'est pas portée ; la
  troisième bulle de présentation parle de lancer une séance ; `consigneParcours` ne
  mentionne plus `[PARCOURS]`. Un `[PARCOURS]` égaré est retiré du texte ;
  `parcoursPropose` vaut toujours `false`. `genererParcours` n'est pas porté.
- **Catalogue** : les 94 séances natives sous les 9 catégories natives ; chaque ligne
  donne aussi le type (méditation guidée / respiration) et l'objectif. Le chemin indiqué
  est l'onglet Séances, plus l'Accueil de l'app Flutter.
- **Apple Santé** : l'app native n'envoie jamais de données Santé (elles restent sur
  l'iPhone). Le champ `sante` et la carte `[ANALYSE]` ne sont pas portés ; `consigneSante`
  dit seulement si Santé existe sur l'appareil et que Louane n'en voit rien (le texte
  Firebase annonçait « Android » à tout client envoyant `santeDispo: false`).
- **Non porté** : App Check, vérification RevenueCat et custom claims, quota « nouveaux »
  des comptes anonymes et 40 messages découverte (Flutter seulement), Boussole (en pause).
- **Stats** : les lignes `vigie_louane` vont dans `louane_stats` (ni id de compte, ni
  texte). Entretien : planifier `select public.louane_purge_stale();` chaque jour
  (pg_cron) pour effacer les vieux quotas et les stats de plus de 180 jours.
- **Latence** : le réessai de la Voix ou du Veilleur est sauté s'il reste moins de 3 s
  sur un budget de 30 s, pour répondre avant le délai de 35 s de l'app.
