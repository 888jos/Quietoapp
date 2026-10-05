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

## RevenueCat et Superwall

Superwall pilote les paywalls du nouveau client, mais les droits historiques restent importés depuis RevenueCat. `subscription_accounts` est une projection serveur en lecture seule pour le client ; `subscription_events` et `migration.revenuecat_customers` gardent événements et snapshots bruts.

Ne couper RevenueCat qu’après avoir vérifié : achats actifs, essais, grâce, expiration, restauration, accès promotionnels entreprise et alias. Le retrait de RevenueCat du client n’autorise pas la suppression de ses données historiques.

## Critères de cutover

- nombre d’utilisateurs importés au moins égal au snapshot ;
- nombre de documents Firestore importés au moins égal au snapshot ;
- 35 séances actives dans le catalogue ;
- aucune erreur RLS ou advisor sécurité critique ;
- parité des droits premium sur actif, essai, expiré, annulé et entreprise ;
- tests Apple/anonyme et restauration d’achat sur appareil réel ;
- delta final Firebase/RevenueCat nul, avec manifeste archivé.

En cas d’écart, l’app reste sur Firebase/RevenueCat et l’import peut être rejoué : toutes les écritures utilisent des UPSERT idempotents.
