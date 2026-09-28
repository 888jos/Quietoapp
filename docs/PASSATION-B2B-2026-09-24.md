# Passation — Quieto Entreprise (B2B), au 24/09/2026 (soir)

> ⚠️ **maj 28/09/2026 — ce document est une photo du 24/09.** Depuis : Stripe est passé en réel (24/09 au soir) et un achat réel de test a réussi (25/09) ; l'app 1.0.27 est publiée sur l'App Store et la 1.0.28+39 a été envoyée aux deux stores le 28/09 ; tout vit dans le dépôt unique `~/Desktop/dev/Quieto` depuis le 26/09. Lire donc `QuietoApp/…` = `Quieto/app/…`, `quieto-backend/…` = `Quieto/backend/…`, `quieto-entreprise-site/…` = `Quieto/sites/entreprise/…`, et ce fichier = `Quieto/docs/PASSATION-B2B-2026-09-24.md`. L'état à jour est dans `JOURNAL-QUIETO.md`.

## En une phrase
Tout le circuit B2B marche de bout en bout **en mode test Stripe** : une entreprise paie sur le site, reçoit son code (page merci + e-mail), et ses salariés activent Premium dans l'app. Il reste à passer Stripe en réel, publier le site, publier la mise à jour de l'app et faire le ménage.

Détail jour par jour : `JOURNAL-QUIETO.md`, entrées 💳 du 24/09 et 🏢 du 23/09.

---

## 1. Ce qui est en place

### Le site `quietopro.com` (dossier `~/Desktop/dev/quieto-entreprise-site/`)
- HTML/CSS/JS statique : `index.html`, `tarifs.html`, `merci.html`, `mentions-legales.html`, `cgv.html`, `assets/css/style.css`, `assets/js/` (`ciel.js`, `mouvement.js`, `souffle.js`, `site.js`).
- **Ambiance = l'accueil de l'app** : aurore boréale WebGL (traduction de `aurora.frag` et `stardust.frag`), étoiles qui scintillent, étoiles filantes, lune ivoire. Sur grand écran, la lune glisse dans la marge et passe du croissant à la pleine lune au fil de la page. Le ciel suit la souris, avec des constellations autour du curseur.
- **Sections** (structure inspirée d'organizations.headspace.com) :
  - hero : « Le soutien mental de toute votre équipe » ;
  - « Le stress ne s'arrête pas en quittant le bureau » : au travail, puis l'actualité en rentrant, avec le widget de la vraie catégorie « Actualité & Surcharge mentale » ;
  - « Une journée avec Quieto » : onglets de Camille, dont le ciel change avec l'heure ;
  - « Trente secondes pour souffler » : bulle de respiration à essayer ;
  - Pourquoi agir, Pourquoi Quieto, Pour qui, Tarifs, FAQ, formulaire de démo.
- **Choix de Paul à respecter :**
  - ne pas vendre « l'employeur ne voit rien » aux employeurs (ils veulent du contrôle) : l'argument est « prendre soin de son équipe », au travail et face à l'actualité ;
  - adresse de contact **quieto@cofonde.com** : sur ordinateur, un clic ouvre une fenêtre « Nous écrire » (copier, Gmail, Outlook, messagerie) ;
  - délai affiché : « Nous vous répondons en moins de 24 heures » ;
  - logo lotus **crème** (seul le favicon reste turquoise) ;
  - titre de la page merci : « Bienvenue dans Quieto / *Vos équipes vont adorer* », sans point final.
- **Tarifs** : calculateur de 10 à 999 salariés, grille Headspace de 56,04 € à 44,88 € HT par salarié et par an, mensuel = annuel ÷ 10. Prix **validés par Paul**, ne pas proposer de les baisser.
- **Aperçu local** : double-clic sur `~/Desktop/dev/Voir le site Quieto Entreprise.command` (http://127.0.0.1:8766).
- **En ligne** : quietopro.com (Namecheap + Netlify). ⚠️ **C'est encore l'ANCIENNE version** : il faut republier le dossier.
- Liens CSS/JS versionnés en `?v=14` : **augmenter le numéro à chaque modification**, sinon les navigateurs gardent l'ancien fichier.

### Le paiement Stripe (compte Cofonde) — mode TEST installé
- Whop a été abandonné pour Stripe (factures au nom de l'entreprise, SEPA annuel ou mensuel, espace client).
- **Fonctions déployées** (`quieto-backend/functions/index.js`, section « ACCÈS ENTREPRISE ») :
  - `paiementEntreprise` : crée la page de paiement Stripe au prix exact (calculé côté serveur par `tarifEntreprise` et `GRILLE_ENTREPRISE`, qui fait foi) ;
  - `stripe` : webhook ; relit l'abonnement chez Stripe, crée ou met à jour `entreprises/{sub_…}`, génère le code et envoie l'e-mail à la RH ;
  - `commandeEntreprise` : donne le code à la page merci (`merci.html?session_id=…`) ;
  - déjà en prod depuis le 23/09 : `accesEntreprise` (activation du code dans l'app), `synchroniserAbonnement` (prolongation à chaque lancement), `supprimerDonnees`.
- **Pas encore déployé :** `demandeEntreprise` (formulaire de démo). Il envoie à `REPONSE_RAPPEL = contact@cofonde.com`, une constante partagée avec d'autres e-mails de l'app : il faut trancher l'adresse avec Paul (probablement quieto@cofonde.com, via une constante B2B séparée).
- **Réglages importants :**
  - « Managed Payments » (Stripe vendeur officiel) est **coupé** par session : Cofonde reste le vendeur ;
  - moyens de paiement : **carte + SEPA** (Apple Pay et Google Pay passent par la carte) ;
  - version d'API Stripe figée à `2024-06-20` ; appels en `fetch`, sans bibliothèque.
- **Règles d'accès :**
  - Premium jusqu'à la fin de la période payée **+ 10 jours** ;
  - premier prélèvement SEPA en cours : **14 jours provisoires**, étendus dès que Stripe confirme ;
  - renouvellement impayé : seule la période précédente reste acquise ;
  - le code est limité au **nombre de places payées** (1 place = 1 compte Apple ou Google) ;
  - aucune entreprise n'est créée sans le nom saisi par l'acheteur (bug corrigé : Stripe envoie ses événements dans le désordre).
- **Configuration test :**
  - produit `prod_VJs0Jx0eXwTf9u`, portail client (lien de test), webhook `we_1UJEGID5WmwwYlVctCzJPK0R` ;
  - secrets `STRIPE_SECRET_KEY` et `STRIPE_WEBHOOK_SECRET` ;
  - `functions/.env` : `STRIPE_PRODUIT`, `STRIPE_PORTAIL`, `SITE_ENTREPRISE=https://quietopro.com`.
- **Outil admin** `quieto-backend/scripts/entreprise.js` : `liste`, `creer`, `prolonger`, `places`, `renommer`, `membres`, `retirer`, `desactiver`, **`stripe-installer <site>`** (produit, portail, webhook, secret, .env en une commande) et **`stripe-places CODE n`** (change le nombre de places, avec prorata Stripe).
- **Achat test réussi** (Paul, 25 places, carte 4242) : entreprise de test « Grand Frais », code **GRAND-5DPC**, dans la vraie base Firestore.

### Après l'achat
1. Page merci : code en grand (Copier), adresse où l'e-mail est parti, 3 étapes, message à transférer (Copier), lien vers l'espace client Stripe.
2. E-mail à la RH : **structure validée par Paul, à garder**. La présentation de Quieto dans le message à transférer a été réécrite (`messageATransferer`, partagé avec la page merci).
3. La RH transfère le message. Chaque salarié : télécharge Quieto → Profil → « Accès offert par mon entreprise » → connexion Apple ou Google → code → « Premium offert par X » → Activer.
4. Renouvellement automatique par Stripe ; l'accès se prolonge tout seul.

### L'app (`QuietoApp`, version 1.0.26+37 dans `pubspec.yaml`)
- Écran « Accès offert par mon entreprise » dans Profil (`lib/features/profile/presentation/widgets/acces_entreprise_sheet.dart`, service `lib/core/services/acces_entreprise.dart`). **Rhabillé le 24/09** : fond nuit, gouache en tête selon l'étape, titres en Cormorant crème, plus d'emoji, encadré « abonnement personnel » couleur aube (affiché seulement si la personne a déjà un abonnement perso).
- Carte Premium « Premium offert par X ».
- ⚠️ **Rien de tout ça n'est publié ni commité** (ni l'app, ni le backend ; le site n'est pas un dépôt git).

---

## 2. Ce qui reste à faire (dans l'ordre)

**Paul**
1. **Publier le site** : Netlify → site quietopro → Deploys → glisser le dossier `quieto-entreprise-site`.
2. **Deuxième achat test** sur quietopro.com (carte `4242 4242 4242 4242`, date future, n'importe quel code), pour voir la nouvelle page merci en vrai.
3. **Réglages Stripe**, en mode réel :
   - image de marque : logo carré, couleurs `#0A1628` et `#5CE0D8` ;
   - Facturation → Factures : mention « TVA non applicable, art. 293 B du CGI » si le comptable confirme ;
   - e-mails clients : reçus, factures, rappels de renouvellement ;
   - moyens de paiement : carte, SEPA, Apple Pay et Google Pay activés.
   - Paramètres → Billing → Factures : **préfixe `QUIETO`**, **bas de page** légal (Cofonde SASU, RCS Toulouse 103 650 057, « TVA non applicable, article 293 B du CGI », pénalités de retard, indemnité de 40 €, pas d'escompte), postes en **HT** (fait en test le 24/09, à refaire en réel si les réglages sont séparés) ;
   - Paramètres → Entreprise → E-mails client : **Paiements réussis** activé (reçu + facture PDF) ;
   - Netlify : badge « Powered by Netlify » coupé (Project configuration → General).
4. **Clé Stripe RÉELLE** : clé restreinte, modèle « Abonnements récurrents et facturation », avec en écriture Checkout Sessions, Customers, Subscriptions, Products, Prices, portail client et Webhook Endpoints. Paul la pose lui-même : `cd ~/Desktop/dev/quieto-backend && firebase functions:secrets:set STRIPE_SECRET_KEY` (la coller seulement quand la commande demande « Enter a value »).
5. **Comptable** : TVA (Cofonde en franchise, art. 293 B) et relecture des CGV.

**Claude**
6. Une fois la clé réelle posée :
   - `node scripts/entreprise.js stripe-installer https://quietopro.com` (recrée produit, portail et webhook en réel) ;
   - redéployer `stripe`, `paiementEntreprise` et `commandeEntreprise` ;
   - premier achat réel avec un **code promo à 100 %** créé dans Stripe, pour tester sans payer ;
   - vérifier : webhook, Firestore, e-mail, page merci, activation dans l'app.
7. **Ménage des données de test** :
   - supprimer l'entreprise « Grand Frais » (`entreprises/sub_1UJEYgD5WmwwYlVcljZNpfdY`, ses `membres` et les liens `acces_entreprise` si Paul l'a activée) ;
   - supprimer les éventuels autres achats test ;
   - garder l'entreprise de démo **QUIETO-MST8** (review Apple).
8. ✅ **Formulaire de démo** : reçu sur quieto@cofonde.com (`CONTACT_ENTREPRISE`), `demandeEntreprise` déployée le 24/09 au soir.
9. ✅ **Mentions légales** : hébergeur Netlify corrigé (24/09 au soir).
10. ✅ **Petites décisions** : titres sans point final ; « Avant le comité » gardé (24/09 au soir).
11. **Mise à jour de l'app** :
    - publier la version avec l'écran entreprise ;
    - builds release : Xcode fermé, `build-release.sh ipa`, numéro de build bumpé automatiquement, jamais d'archive depuis Xcode (les `dart-define` seraient perdus) ;
    - note pour App Review dans le journal (code de démo QUIETO-MST8).
12. **Commit** de QuietoApp et quieto-backend. Jamais de `git checkout` sur du travail non commité.
13. **Vigie** : les événements `entreprise_code`, `entreprise_activee` et `entreprise_activation_echec` ; `VIGIE.md` n'est pas à jour (agent quieto-vigie).
14. **Docs** : passer l'agent quieto-scribe.

**Idées pour plus tard, non demandées :**
- lien de paiement pré-rempli pour Paul après un rendez-vous (nom, e-mail, nombre de places) ;
- facture à 30 jours payable par virement pour les grandes entreprises et les CSE.

---

## 3. Façon de travailler avec Paul
- Messages **courts et simples**, comme à un débutant quand il s'agit de technique (Stripe, terminal, clés).
- Lui poser la question avant un gros changement ; c'est lui qui teste (simulateur iPhone 17 `296E4FC6-3DBE-4DED-B1F4-2A60D02E56A4` ou son iPhone 11 branché, `flutter -d 00008030-001029293CC3402E`).
- Jamais de clé ou de mot de passe tapé par Claude : Paul les colle lui-même dans le terminal.
- Tenir `JOURNAL-QUIETO.md` à jour à chaque changement.

---

## Prompt pour la prochaine discussion (à copier-coller)

> On termine **Quieto Entreprise** (l'offre B2B) et on envoie la mise à jour. Lis d'abord `~/Desktop/dev/PASSATION-B2B-2026-09-24.md` (état complet et liste des tâches), puis les entrées 💳 du 24/09 et 🏢 du 23/09 de `~/Desktop/dev/JOURNAL-QUIETO.md`.
>
> **Où on en est :** tout marche de bout en bout en **mode test Stripe**.
> - Le site `quietopro.com` (dossier `~/Desktop/dev/quieto-entreprise-site/`) a le ciel animé de l'app, le calculateur de tarifs, et une page merci qui affiche le code tout de suite.
> - Le paiement Stripe (Cofonde vendeur, carte + SEPA, abonnement annuel ou mensuel) crée automatiquement l'entreprise, son code et l'e-mail à la RH.
> - Dans l'app, Profil → « Accès offert par mon entreprise » active Premium avec le code. L'écran vient d'être rhabillé.
> - Rien n'est publié : ni le site (l'ancienne version est en ligne), ni l'app ; rien n'est commité.
>
> **Ce que je veux maintenant, dans l'ordre :**
> 1. m'accompagner pour publier le site sur Netlify et refaire un achat test ;
> 2. passer Stripe en **réel** : je pose la clé réelle, tu lances `stripe-installer`, tu redéploies, et on teste avec un code promo à 100 % ;
> 3. faire le ménage des données de test (garder la démo QUIETO-MST8) ;
> 4. régler les petits points en attente (adresse du formulaire de démo, hébergeur dans les mentions légales, points des titres, « Avant le comité ») ;
> 5. préparer et envoyer la **mise à jour de l'app** avec l'écran entreprise (build release, note App Review), puis commit.
>
> Explique-moi chaque étape simplement, comme à un débutant, avec des messages courts.
