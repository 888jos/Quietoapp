# Quieto Entreprise (B2B) sur Supabase

Portage des fonctions Firebase du B2B (`backend/functions/index.js`, section
« ACCÈS ENTREPRISE ») vers des Edge Functions Supabase. **Firebase reste en
ligne et inchangé tant que la bascule n'est pas faite.** Rien n'est déployé.

## Correspondance

| Firebase (`us-central1-quieto-06`) | Supabase (`/functions/v1/…`) | Appelant | JWT Supabase |
|---|---|---|---|
| `demandeEntreprise` (POST) | `enterprise-demo` | site, formulaire de démo | non |
| `paiementEntreprise` (POST) | `enterprise-checkout` | site, page Tarifs | non |
| `commandeEntreprise` (GET `?session=cs_…`) | `enterprise-order` | site, page merci | non |
| `factureEntreprise` (GET `?u=…`) | `enterprise-invoice` | lien de l'e-mail et de la page merci | non |
| `stripe` (webhook) | `stripe-webhook` | Stripe (en-tête `Stripe-Signature`) | non |
| `accesEntreprise` (callable) | `enterprise-access` | app (salarié connecté) | **oui** |
| `synchroniserAbonnement` (prolongation) | trigger SQL `enterprises_propagate_access` | — | — |
| `quitterEntreprise` (suppression de compte) | `on delete cascade` depuis `profiles` | `account-data` DELETE | — |

`verify_jwt = false` est déclaré dans `supabase/config.toml` pour les cinq
fonctions publiques. Code partagé : `_shared/stripe.ts` (API Stripe en `fetch`,
version figée `2024-06-20`, signature de webhook en Web Crypto) et
`_shared/entreprise.ts` (grille de prix, codes, quotas, Resend, textes).

Données (migration `20261007091000_entreprise_supabase.sql`, RLS fermée,
`service_role` uniquement) :

| Firestore | Supabase |
|---|---|
| `entreprises/{id}` | `public.enterprises` (id = `sub_…` ou id Firestore) |
| `entreprises/{id}/membres/{uid}` + `acces_entreprise/{uid}` | `public.enterprise_access` étendue (`enterprise_id`, `joined_at`) : une ligne = une place |
| `demandes_entreprise` | `public.enterprise_demo_requests` |
| `quota_ip` / `quota_uid` | `private.rate_limits` + `public.consume_rate_limit()` |

`public.user_has_premium()` donnait déjà Premium quand `enterprise_access.granted_until > now()` :
aucun changement nécessaire. `granted_until` = fin de période payée + 10 jours.

## Secrets (Edge Functions)

À poser par Paul lui-même (jamais tapés par Claude), une valeur à la fois :

```sh
supabase secrets set --project-ref <PROJET> STRIPE_SECRET_KEY        # sk_… ou rk_… (clé restreinte)
supabase secrets set --project-ref <PROJET> STRIPE_WEBHOOK_SECRET    # whsec_… du NOUVEAU endpoint (voir plus bas)
supabase secrets set --project-ref <PROJET> RESEND_API_KEY           # même clé que RESEND_KEY côté Firebase
```

Paramètres non secrets (même mécanisme `supabase secrets set`) :

| Nom | Valeur | Équivalent Firebase |
|---|---|---|
| `STRIPE_PRODUIT` | `prod_…` (produit « Quieto Entreprise ») | `functions/.env` |
| `STRIPE_PORTAIL` | `https://billing.stripe.com/p/login/…` | `functions/.env` |
| `SITE_ENTREPRISE` | `https://quietopro.com` | `functions/.env` |

Déjà présents pour les autres fonctions : `SUPABASE_URL` (fourni par Supabase)
et `SUPABASE_SECRET_KEY` (clé secrète/service, lue par `_shared/http.ts`).
Sans `STRIPE_SECRET_KEY` ou `SITE_ENTREPRISE`, `enterprise-checkout` répond 503
et le site affiche « Le paiement en ligne ouvre très bientôt » (comme avant).

## Webhook Stripe

URL à déclarer dans Stripe (Développeurs → Webhooks → Ajouter un endpoint),
**en plus** de l'endpoint Firebase pendant la préparation, puis à sa place :

```
https://<PROJET>.supabase.co/functions/v1/stripe-webhook
```

Version d'API `2024-06-20`, événements (les mêmes que `scripts/entreprise.js`) :
`checkout.session.completed`, `checkout.session.async_payment_succeeded`,
`checkout.session.async_payment_failed`, `customer.subscription.created`,
`customer.subscription.updated`, `customer.subscription.deleted`,
`invoice.paid`, `invoice.payment_failed`.

Chaque endpoint a son propre `whsec_…` : c'est celui du nouvel endpoint qui va
dans `STRIPE_WEBHOOK_SECRET` côté Supabase.

## Déploiement (à faire plus tard, pas maintenant)

```sh
supabase link --project-ref <PROJET>
supabase db push                       # applique 20261007091000_entreprise_supabase.sql
supabase functions deploy enterprise-demo enterprise-checkout enterprise-order enterprise-invoice stripe-webhook enterprise-access
deno test --allow-net=none supabase/functions/_shared   # tests (dont la signature Stripe)
```

Puis dans `sites/entreprise/assets/js/site.js`, remplacer `<PROJET>` dans la
constante `API` et republier le site (le cache est déjà passé à `?v=18`).

## Bascule (ordre conseillé)

0. **Décision préalable** : l'app Flutter (Android et anciennes versions iOS)
   active toujours les codes via `accesEntreprise` sur Firestore, et se
   prolonge via `synchroniserAbonnement` + RevenueCat. Après la bascule, une
   entreprise **nouvelle** n'existe que dans Supabase : ses codes ne marchent
   que dans l'app native. Les entreprises existantes, elles, continuent dans les
   deux mondes jusqu'à leur prochain renouvellement, qui ne sera vu que par
   Supabase. Basculer quand l'app native est celle des stores (ou accepter ce
   décalage pour Android).
1. Appliquer la migration, déployer les fonctions, poser les secrets (mode test
   Stripe d'abord si possible).
2. Ajouter l'endpoint webhook Supabase dans Stripe (test), faire un achat test
   carte `4242…` sur une copie locale du site pointant vers Supabase ; vérifier
   `enterprises`, l'e-mail, la page merci, la facture, puis l'activation.
3. Snapshot + import Firestore (section suivante), juste avant la bascule.
4. En réel : ajouter l'endpoint Supabase, **désactiver** l'endpoint Firebase
   (sinon deux e-mails de code pour un nouvel achat : les clés d'idempotence
   Resend diffèrent car les codes générés diffèrent), remplacer `<PROJET>` dans
   `site.js`, republier le site.
5. Refaire l'import (idempotent) pour récupérer ce qui a changé entre-temps,
   puis contrôler les compteurs (requêtes plus bas).
6. Garder les fonctions Firebase quelques semaines en lecture (page merci des
   anciens liens, liens de facture déjà envoyés pointant vers
   `cloudfunctions.net/factureEntreprise`) avant de les retirer.

## Migration des données Firestore

Les données sont simples et le pipeline existe déjà (`backend/migration`) :
`snapshot.mjs` exporte **toutes** les collections Firestore, sous-collections
comprises, et `import.mjs` les range brutes dans `migration.firebase_documents`
(plus les comptes dans `profiles`). La migration ajoute une fonction SQL qui
transforme ces documents :

```sh
cd backend/migration
npm run snapshot                              # identifiants Firebase admin requis
npm run import -- snapshots/<horodatage>      # SUPABASE_DB_URL requis
```

```sql
select migration.import_firestore_enterprises();
-- {"enterprises": n, "members": n, "demo_requests": n}
```

- `entreprises/{id}` → `enterprises` (les champs Firestore bruts sont gardés
  dans `legacy_data`) ; `finMs` → `paid_until`, `nomManuel` → `name_locked`,
  `source: "manuel"` → `manual`.
- `entreprises/{id}/membres/{uid}` → `enterprise_access` sous l'**UID Firebase**
  (`granted_until` = max(`finAccordeeMs`, couverture actuelle)). Quand la
  personne se connecte avec Apple dans l'app native, `account-data`
  (`link-legacy`) appelle `link_legacy_firebase_account()`, redéfinie ici pour
  déplacer la place (et `enterprise_id`) vers le compte Supabase et la libérer
  sous l'UID Firebase.
- Membres dont l'UID n'est pas dans `profiles` (compte Firebase supprimé) :
  ignorés. `acces_entreprise/{uid}` (lien inverse) n'est pas nécessaire.
- `demandes_entreprise` → `enterprise_demo_requests` (dédoublonné sur e-mail + date).

Contrôles :

```sql
select id, name, code, seats, active, paid_until,
  (select count(*) from public.enterprise_access a where a.enterprise_id = e.id) as membres
from public.enterprises e order by created_at;
```

À comparer avec `node scripts/entreprise.js liste` côté Firebase (`nbMembres`).
Ménage prévu par la passation : supprimer l'entreprise de test « Grand Frais »
(`delete from public.enterprises where id = 'sub_1UJEYgD5WmwwYlVcljZNpfdY';`,
les places suivent par cascade) et garder la démo `QUIETO-MST8`.

## Administration (remplace `backend/scripts/entreprise.js`, pas encore porté)

En SQL (éditeur Supabase), en attendant un script :

```sql
-- créer une entreprise hors Stripe (virement, démo App Review)
insert into public.enterprises (id, name, code, code_key, seats, paid_until, active, source)
values ('manuel-acme', 'Acme', 'ACME-7K2P', 'ACME7K2P', 20, now() + interval '1 year', true, 'manual');
-- prolonger (les membres suivent tout seuls)
update public.enterprises set paid_until = paid_until + interval '1 year' where code_key = 'ACME7K2P';
-- renommer à la main (le webhook ne l'écrase plus)
update public.enterprises set name = 'Acme France', name_locked = true where code_key = 'ACME7K2P';
-- retirer un membre
delete from public.enterprise_access where user_id = '<uuid>' and enterprise_id = '<id>';
```

`stripe-places` (changement de quantité avec prorata) se fait dans le
Dashboard Stripe : le webhook `customer.subscription.updated` met `seats` à jour.

## App iOS native

L'app native (`app/ios/QuietoNative`) **n'a pas encore d'écran** « Accès offert
par mon entreprise » (seul un libellé de `AccountModels.swift` évoque un accès
fourni par l'entreprise). Aucune UI n'a été créée. Contrat de l'endpoint, à
appeler avec `QuietoSupabaseRepository.invokeFunction("enterprise-access", …)`
(jeton de session dans `Authorization: Bearer`) :

```
POST /functions/v1/enterprise-access
{"code": "ACME-7K2P"}                    → 200 {"nom": "Acme"}
{"code": "ACME-7K2P", "confirmer": true} → 200 {"ok": true, "nom": "Acme", "finMs": 1790000000000, "premium": true}
```

Erreurs : `{"error", "raison", "message"}` (message déjà rédigé pour l'écran) :
403 `compte` (compte anonyme : se connecter avec Apple d'abord), 404 `inconnu`,
410 `inactif`, 409 `complet`, 429 `quota` (30 essais / jour / réseau, 10 / compte),
503 `unavailable`. Après succès, `has_premium_access()` / `user_has_premium()`
répondent vrai : l'app n'a qu'à relire son droit (comme après `subscription-sync`).

## Ce qui diffère de Firebase

- **Premium** : écrit dans `enterprise_access` (lu par `user_has_premium`) au
  lieu d'un droit promotionnel RevenueCat ; plus d'appel à RevenueCat.
- **Prolongation** immédiate au webhook (trigger SQL) au lieu de paresseuse au
  lancement de l'app ; toujours « jamais raccourcie », comme avec RevenueCat.
- **Places** comptées (`count(*)` sous verrou de la ligne entreprise) au lieu
  d'un compteur `nbMembres` ; suppression de compte = place libérée par cascade.
- **Supprimer une entreprise** retire aussitôt l'accès de ses membres (cascade) ;
  chez Firebase, le Premium RevenueCat déjà accordé restait jusqu'à sa fin.
- **Compte requis** : compte Supabase non anonyme (Apple dans l'app native) au
  lieu d'« Apple ou Google ». Le message dit « Connecte-toi avec Apple ».
- **IP** pour les quotas : première entrée de `X-Forwarded-For` (convention de
  `louane-proxy`), hachée ; fenêtre « jour de Paris » comme avant.
- **Codes HTTP** des erreurs d'activation (callable → HTTP) : voir plus haut.
- `enterprise-invoice` n'accepte que GET (le lien est un téléchargement).
- Les liens de facture des nouveaux e-mails pointent vers
  `<SUPABASE_URL>/functions/v1/enterprise-invoice?u=…`.
