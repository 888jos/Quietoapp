# Migration Firebase + RevenueCat vers Supabase

Cette migration est conçue pour être **réversible et sans perte**. Firebase et RevenueCat ne sont pas supprimés pendant la transition. Les données brutes sont conservées dans le schéma privé `migration`, puis projetées vers les tables applicatives.

## Ce qui est préservé

- tous les utilisateurs Firebase Auth, fournisseurs, claims et métadonnées ;
- tous les documents Firestore, y compris les sous-collections ;
- chaque fiche RevenueCat accessible par l’UID Firebase, avec le JSON original ;
- les événements RevenueCat futurs, dédupliqués par identifiant ;
- la correspondance `Firebase UID = RevenueCat app_user_id` déjà utilisée en production ;
- profil, préférences, progression, écoutes, programmes, conversations et mémoire Louane dans des tables dédiées.

Les snapshots sont en NDJSON et accompagnés d’un manifeste SHA-256. Le script d’import refuse un fichier dont le checksum ne correspond pas.

## Phases de bascule

1. Créer un projet Supabase Quieto distinct. Ne pas utiliser les projets Supabase existants d’un autre produit.
2. Appliquer `supabase/migrations/` sur une branche de développement, puis contrôler les advisors sécurité et performance.
3. Dans Supabase Auth, activer l’intégration Firebase tierce pour `quieto-06` et l’authentification anonyme.
4. Exécuter `npm run claims` pour ajouter `role: authenticated` aux utilisateurs Firebase existants sans écraser `premium` ni les autres claims.
5. Déployer la version Firebase modifiée : `synchroniserAbonnement` maintient ensuite `role` et `premium` ensemble.
6. Créer un snapshot complet Firebase + RevenueCat et le copier vers deux emplacements chiffrés indépendants.
7. Importer le snapshot dans Supabase, puis exécuter la vérification de parité.
8. Configurer le webhook RevenueCat Supabase en parallèle du webhook Firebase. Garder les deux actifs jusqu’à parité des événements et droits.
9. Configurer l’app native avec l’URL et la clé **publishable** Supabase. Ne jamais embarquer `SUPABASE_SECRET_KEY`, `SUPABASE_DB_URL`, un compte de service Firebase ou `RC_API_KEY`.

## Fonctions natives et bascule contrôlée

Les fonctions `supabase/functions/account-data` et `supabase/functions/louane-proxy` sont prévues pour les opérations qui ne doivent jamais être exécutées avec une clé publique. Elles exigent `SUPABASE_SECRET_KEY` côté Edge Function. `louane-proxy` vérifie le JWT Supabase, puis appelle la Cloud Function Firebase historique avec `QUIETO_FIREBASE_PROXY_SECRET`; le même secret doit être déclaré comme `SUPABASE_PROXY_SECRET` dans Firebase Functions. Cette passerelle conserve les prompts, quotas, veilleur et règles de sécurité existants pendant la migration.

Le bucket privé `session-audio` et ses politiques sont créés par `20261005170300_native_client_support.sql`. Les pistes gratuites peuvent être lues sans abonnement; les pistes premium nécessitent une ligne d’entitlement serveur valide. L’app ne reçoit qu’une URL signée temporaire et ne la considère jamais comme un fichier téléchargé avant son stockage local.

Avant déploiement, exécuter `node backend/migration/validate-sql.mjs`, puis appliquer les migrations et lancer les advisors Supabase. Le déploiement distant n’est pas effectué depuis ce dépôt tant que l’URL/projet Supabase et les secrets ne sont pas fournis.
10. Basculer progressivement les lectures puis les écritures. Le cutover n’est autorisé qu’après deux snapshots cohérents et un delta final à zéro.

## Commandes locales

Depuis `backend/migration` :

```sh
npm ci
npm run validate:sql

FIREBASE_SERVICE_ACCOUNT=/chemin/service-account.json \
FIREBASE_PROJECT_ID=quieto-06 \
RC_API_KEY='clé RevenueCat secrète' \
npm run snapshot

SUPABASE_DB_URL='connexion Postgres Supabase avec SSL' \
npm run import -- /chemin/du/snapshot

SUPABASE_DB_URL='connexion Postgres Supabase avec SSL' \
npm run verify -- /chemin/du/snapshot
```

Les secrets doivent rester dans le trousseau, le gestionnaire de secrets ou des variables d’environnement locales. Ne pas les écrire dans le dépôt ni dans une conversation.

## Authentification

La transition utilise deux mécanismes compatibles :

- les anciennes versions continuent à émettre des JWT Firebase ; Supabase les accepte via Third-party Auth ;
- la cible Swift utilise Supabase Auth directement avec compte anonyme et Sign in with Apple.

Les tables utilisent `user_id text` afin d’accepter temporairement les UID Firebase et les UUID Supabase. Les politiques RLS comparent toujours ce champ au `sub` du JWT et imposent un émetteur Quieto valide.

Pour migrer aussi les mots de passe Firebase sans réinitialisation, utiliser l’outil officiel `supabase-community/firebase-to-supabase` avec les paramètres SCRYPT récupérés dans Firebase Authentication. Quieto utilise surtout Apple, Google et l’anonyme : ces identités doivent être testées sur une branche avant cutover, car une session Firebase existante ne devient pas automatiquement une session Supabase.

## Superwall remplace RevenueCat (paywall strict)

Quieto est en **paywall strict** : sans abonnement actif, rien n'est accessible (séances, audio, Louane). La décision d'accès est prise côté serveur par `public.user_has_premium(user_id)` (migration `20261006120000_hard_paywall_superwall.sql`), et côté app par `QuietoSuperwallService`.

**Principe** : un abonnement est identifié par son `original_transaction_id` App Store, pas par un compte. Il suit donc l'identifiant Apple de la personne à travers une réinstallation, un nouveau compte anonyme ou le passage de l'app Flutter (UID Firebase) à l'app native (UUID Supabase).

| Source | Fonction | Rôle |
|---|---|---|
| App (StoreKit 2) | `subscription-sync` | À chaque lancement, retour au premier plan, achat et restauration, l'app envoie ses transactions signées. Le serveur vérifie la chaîne de certificats Apple (racine Apple Root CA G3 épinglée) et lie l'abonnement à l'utilisateur. |
| Superwall | `superwall-webhook` | Renouvellements, annulations, problèmes de paiement, remboursements et expirations, même quand l'app est fermée. La signature Svix est vérifiée. |
| RevenueCat | `revenuecat-webhook` | Il reste actif tant que l'app Flutter est en ligne. Il passe par le même point d'écriture, donc un événement rejoué n'écrase jamais un état plus récent. |

Toutes les écritures passent par `public.apply_store_subscription()`, réservée au service role. Les règles :
- le traitement est atomique et ordonné ;
- une annulation garde l'accès jusqu'à la fin de la période payée ;
- un remboursement le coupe tout de suite.

### À configurer avant la bascule

1. **Superwall** :
   - créer le placement `onboarding_trial` (paywall de fin d'onboarding, avec l'essai gratuit). L'app envoie les attributs `firstName`, `goal`, `minutes` et `planTitle` pour personnaliser le texte (`{{ user.firstName }}`) ;
   - créer le placement `quieto_hard_paywall`, avec une campagne qui montre le paywall aux non-abonnés ;
   - y rattacher les produits App Store et l'entitlement `premium` ;
   - mettre la clé publique iOS dans `project.yml` (`SUPERWALL_API_KEY`), puis lancer `xcodegen generate`.
2. **Webhook Superwall** : dans Superwall, Settings → Webhooks, URL `https://<projet>.supabase.co/functions/v1/superwall-webhook`. Copier le secret `whsec_…` dans le secret Supabase `SUPERWALL_WEBHOOK_SECRET`.
3. **Secrets Supabase** :
   - `APPLE_BUNDLE_ID`, l'identifiant de l'app qui sera publiée ;
   - `SUPABASE_SECRET_KEY` ;
   - `QUIETO_FIREBASE_PROXY_SECRET`, la même valeur que `SUPABASE_PROXY_SECRET` dans Firebase.
4. **App Store Server Notifications** : elles doivent atteindre Superwall (suivre le guide de migration RevenueCat → Superwall). RevenueCat peut continuer à les recevoir en parallèle jusqu'au retrait de l'app Flutter.
5. **Bundle ID** : l'app native utilise encore `com.quietoapp.app.native`. Les abonnements App Store appartiennent à une fiche d'app. Pour que les abonnés actuels gardent leur abonnement, l'app native doit être publiée **sous `com.quietoapp.app`**, en mise à jour de l'app Flutter. Changer `PRODUCT_BUNDLE_IDENTIFIER` et `APPLE_BUNDLE_ID` au moment de la publication.
6. **Déploiement** :

   ```sh
   supabase db push
   supabase functions deploy subscription-sync superwall-webhook revenuecat-webhook louane-proxy account-data
   ```

   Le `firebase deploy` des fonctions doit être fait en même temps que les nouvelles fonctions Supabase, car le pont transmet maintenant le statut premium.

### Anciens utilisateurs de l'app Flutter

- **Abonnement App Store** : il est retrouvé automatiquement au premier lancement (`subscription-sync`), sans action de la personne.
- **Compte** : avec « J'ai déjà un compte (Apple) », `account-data` (action `link-legacy`) relie le compte Firebase qui utilisait le même identifiant Apple. La personne retrouve sa mémoire Louane et ses compteurs (Louane continue de tourner sous l'UID Firebase), son accès entreprise et un abonnement Android importé jusqu'à son expiration.
- **Cas non couverts** : les comptes Firebase anonymes ou Google ne peuvent pas être reliés automatiquement.

Ne couper RevenueCat qu'après avoir vérifié : achats actifs, essais, période de grâce, expiration, restauration et accès entreprise. Le retrait de RevenueCat du client n'autorise pas la suppression de ses données historiques.

### Tests

```sh
# depuis supabase/functions
npx deno test _shared/
npx deno check */index.ts
```

- `npx deno test _shared/` couvre la vérification JWS Apple sur une chaîne de test, la signature Svix (vecteur de référence) et la conversion des événements.
- `npx deno check */index.ts` contrôle les types des fonctions.

## Critères de cutover

- nombre d’utilisateurs importés au moins égal au snapshot ;
- nombre de documents Firestore importés au moins égal au snapshot ;
- 35 séances actives dans le catalogue ;
- aucune erreur RLS ou advisor sécurité critique ;
- parité des droits premium sur actif, essai, expiré, annulé et entreprise ;
- tests Apple/anonyme et restauration d’achat sur appareil réel ;
- delta final Firebase/RevenueCat nul, avec manifeste archivé.

En cas d’écart, l’app reste sur Firebase/RevenueCat et l’import peut être rejoué : toutes les écritures utilisent des UPSERT idempotents.
