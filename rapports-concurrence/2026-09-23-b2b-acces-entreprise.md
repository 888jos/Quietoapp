# B2B : comment Calm, Headspace et Petit BamBou donnent l'accès via l'employeur

Recherche du 23/09/2026, menée par 4 agents : Calm, Headspace, le marché français et la technique/règles des stores. Les sources principales sont les centres d'aide officiels (lus en entier via l'API Zendesk), les guides admin en PDF, les pages d'inscription en direct et l'API de prix publique de Calm. Chaque chiffre a sa source en bas de section. **[NON VÉRIFIÉ]** = pas confirmé.

---

## 0. En bref

**Le principe est le même partout :**
- Le salarié garde **son compte perso** Quieto.
- L'avantage employeur vient **se greffer dessus**.
- L'entreprise paie **au siège acheté par an**, hors de l'App Store, par carte ou facture.
- L'app ne fait que **vérifier que la personne a droit à l'avantage**, puis débloque Premium.

**Le parcours dans l'app chez Calm** (le plus proche de ce que tu as vu) :

> Profil → ⚙️ Paramètres → **« Link Organization Subscription »** → taper le **nom de l'entreprise** (autocomplétion « Did you mean: ») → **Continue** → saisir **un identifiant** (e-mail pro, n° d'employé, code d'accès `C-56K9L1` ou code de groupe `Calm2026`) → **Submit** → « Congratulations! » → Premium actif.

Le champ demandé dépend de ce que l'entreprise a choisi. Si l'entreprise utilise le SSO, le salarié est redirigé vers la page de connexion de sa boîte.

**Headspace** fait surtout ça sur le web :
- Chaque entreprise a un lien unique, `work.headspace.com/<entreprise>/member-enroll`.
- Le salarié crée son compte, puis vérifie qu'il a droit à l'avantage : e-mail pro, ou nom + n° d'employé.
- Il clique ensuite sur un **e-mail d'activation**, puis se connecte dans l'app.
- Dans l'app, il n'y a qu'un bouton « Access through work or health plan » sur l'écran de connexion, pour le SSO.

**Petit BamBou** : l'entreprise distribue un **code**. Le salarié l'active **sur le site uniquement** : « les codes ne peuvent pas être activés sur l'application ».

⚠️ **Deux corrections sur le pitch :**
- **« Plus de la moitié du CA en B2B » n'est pas prouvé.** Headspace annonçait **40 % en 2021** (entreprises + mutuelles), et Calm ne publie pas la répartition. En revanche, le B2B est la partie qui grossit le plus chez les deux, et Sword Health rachète Headspace (annoncé le 16/09/2026).
- **« Les burn-out divisés par plus de 2 » n'est soutenu par aucune étude.** Voir §9 pour les chiffres utilisables.

---

## 1. Le parcours du salarié, étape par étape

### Calm (Calm Business / Calm for Organizations)

**Les points d'entrée :**
- Un **lien unique par entreprise** : `calm.com/b2b/<entreprise>/subscribe`.
- Un **e-mail d'invitation** envoyé par Calm le lendemain de l'import de la liste, avec des relances à 30 et 90 jours.
- Un **QR code** et un modèle d'e-mail fournis à la RH.
- L'intranet de l'entreprise, via SSO.

**Le parcours web :**
1. « Activate 1 Year of Calm Premium for Free ».
2. Le salarié crée un compte **avec son e-mail PERSO**. Le texte affiché : « so you can take your Calm account with you » (pour garder son compte s'il quitte l'entreprise).
3. « Enter your {identifiant} ».
4. « Congratulations! » → bouton « Open Calm App ».

**Le parcours dans l'app** est décrit plus haut. Anciens libellés : « Link Employer Subscription », puis 4 boutons « Redeem via Email / Employer ID / SSO / Group Code ».

**Vérification de l'e-mail :** **aucune** chez Calm Premium. L'identifiant est juste comparé à la liste fournie par l'entreprise. C'est une faiblesse : quelqu'un qui connaît l'e-mail d'un collègue peut prendre sa place.

**Erreurs affichées :**
- « …is not on your organization's eligibility file »
- « …has already been redeemed »
- Un bouton **« Request Access »** envoie une demande à l'admin RH, avec réponse sous une semaine.

**Pour vérifier que ça a marché :** Profil → Paramètres → « Manage Subscription » affiche « You have Calm Premium! ».

### Headspace (Headspace for Work / Organizations)

1. Lien unique de l'entreprise, avec son logo. Trois étapes affichées : **Log in → Verify → Finish**.
2. Question : « Do you have an existing account? » (Oui / Non). Puis prénom, nom, e-mail, mot de passe, ou connexion Apple/Google.
3. **Vérification**, selon ce que l'entreprise a choisi :
   - e-mail pro ;
   - **nom + n° d'employé**, avec un texte d'aide propre à l'entreprise ;
   - prénom + nom + date de naissance + pays.
4. **E-mail d'activation** « Activate your Headspace Plus Subscription » avec un bouton « Verify ». Si le contenu reste verrouillé, c'est presque toujours que ce clic n'a pas été fait.
5. Le salarié télécharge l'app et se connecte.

**Erreur affichée :** « member with this email not present in organizations eligibility data ».

### Petit BamBou 🇫🇷

- L'entreprise, le CSE, une association ou une collectivité achète 3, 6 ou 12 mois pour ses salariés.
- Le salarié va sur `petitbambou.com/fr/activer-carte-cadeau`, se connecte, puis saisit le code.
- L'activation se fait **uniquement sur le web**.
- Petit BamBou Pro (lancé en 11/2023) ajoute un espace admin pour ajouter ou retirer des salariés. L'app est la même que pour le grand public.

### Teale 🇫🇷

- Trois façons d'accéder : e-mail pro (recommandé), e-mail d'invitation, ou bouton **« J'ai un code »**.
- Un salarié qui a déjà l'app passe par l'onglet « Mon invitation », ou « Activer votre invitation » sur iPhone.

---

## 2. Les 4 façons de vérifier qu'un salarié a droit à l'avantage

| Méthode | Qui l'utilise | + | − |
|---|---|---|---|
| **Code d'entreprise** ou lien d'invitation | Calm (« Group Code »), Teale, Petit BamBou | Aucun travail pour la RH, idéal pour TPE et CSE | Le code peut circuler : il faut un plafond de places, une date d'expiration et un seul usage par compte |
| **E-mail pro + code reçu par mail** | Headspace (petites entreprises), Teale | Aucune liste à fournir, prouve que la personne a la boîte mail | Un ancien salarié garde l'accès tant qu'il a sa boîte ; il faut revérifier chaque année |
| **Liste des salariés** (CSV d'e-mails ou de n° d'employé) | Calm, Headspace | Contrôle exact des places ; un salarié absent du nouveau fichier est retiré | La RH doit tenir la liste à jour ; données perso (RGPD) |
| **SSO** (connexion avec le compte de l'entreprise) | Calm, Headspace (grands comptes) | Le plus sûr ; le départ est géré automatiquement | Cher et complexe (WorkOS : 125 $/mois par entreprise) ; réservé aux grands comptes |

**Détails de la liste de salariés chez Calm :**
- Fichier CSV ou XLSX.
- Colonne A : l'identifiant, **sans nom ni prénom**.
- Jusqu'à 3 colonnes de segments (service, site…) pour découper les stats.
- Chaque import **remplace la liste entière**.

**Famille :**
- Calm et Headspace : jusqu'à **5 proches par salarié** (16 ans et plus chez Calm).
- Chez Headspace, l'invitation se fait depuis l'onglet Profil, section « Refer household members ».

---

## 3. Le salarié qui a déjà un abonnement perso

- **Apple ne permet pas au développeur de résilier ou rembourser.** Le salarié doit résilier lui-même.
- **Calm** bloque l'activation tant que le renouvellement automatique est actif. Écran affiché : « Auto-renewal must be cancelled to redeem benefit ».
- **Headspace** active l'avantage tout de suite :
  - Il résilie automatiquement les abonnements achetés sur son site.
  - Pour Apple et Google, il demande au salarié de résilier lui-même.
  - Si l'abonnement annuel a été acheté sur son site il y a moins de 30 jours, il est remboursé. Au-delà, Headspace offre un an à un proche.
- **Historique et statistiques conservés** chez les deux, sans fusion de comptes.

---

## 4. Quand le salarié quitte l'entreprise

- **Calm :** l'accès reste actif **jusqu'à la fin du mois**. Le compte repasse en gratuit avec tout son historique, et un écran **« Renew myself »** propose de s'abonner soi-même.
- **Headspace :** le compte repasse en gratuit, et le salarié reçoit un e-mail qui propose l'abonnement perso (57,99 €/an). Exemple : quand Microsoft a arrêté l'avantage, Headspace a offert **−15 % la 1re année** à ses salariés.
- **Fin du contrat avec l'entreprise :** Headspace coupe l'accès 10 jours après la date de fin.

**C'est une vraie occasion de convertir des utilisateurs.** Le salarié qui part a pris l'habitude de l'app : on lui propose une offre de fidélité.

---

## 5. Ce que reçoit l'entreprise

**Un portail admin sur le web, avec :**
- les places achetées et utilisées ;
- l'import de la liste de salariés ;
- le lien d'inscription et le QR code ;
- le paiement ;
- des kits de communication : modèles d'e-mail et de message Slack/Teams, affiche, calendrier ;
- des webinaires.

**Stats données à l'entreprise : uniquement des totaux anonymes.**
- Calm n'affiche **rien tant que moins de 10 personnes** ont activé leur accès, et applique ce même seuil à chaque segment.
- Stats fournies : taux d'inscription et d'utilisation, types de séances, contenus les plus écoutés.
- « Individual user activity is never shared ».
- **En France, c'est obligatoire de toute façon.** La CNIL : la RH n'a « pas le droit de posséder des informations médicales ».

**Accompagnement :**
- Une personne dédiée au client après l'achat.
- Headspace envoie les supports de lancement sous 48 h.
- Calm fait des enquêtes anonymes 3 mois après le lancement, puis chaque année.

**Taux d'activation réels :**
- ~14 % chez Doctolib (Petit BamBou, 2020).
- 15 % en moyenne chez Moka (chiffre de Moka).
- Jusqu'à 37-40 % avec une grosse campagne de lancement (Quantum Health / Headspace).
- 3-5 % seulement pour les lignes d'écoute psychologique classiques des entreprises.

---

## 6. Les prix

**Calm, en libre-service de 5 à 300 places** (API de prix publique, relevée le 23/09/2026). Prix de référence : 69,99 $.

| Places | $/place/an |
|---|---|
| 5-10 | 63,78 |
| 51-60 | 55,29 |
| 91-100 | 51,08 |
| 151-200 | 44,06 |
| 251-300 | 37,13 |

- Paiement annuel d'avance, par carte ou prélèvement, **sans facture**.
- Renouvellement automatique.
- Des places peuvent être ajoutées en cours d'année (au prorata), jamais retirées.

**Headspace, en libre-service de 10 à 999 places, en euros :**
- 54,02 € (10-49 places) ;
- 51,27 € (50 places et plus) ;
- 44,69 € (250 places et plus) ;
- ~41 € (999 places).

Prix de référence : 57,99 €. Paiement par carte uniquement, sans renouvellement automatique. Au-delà de 1 000 places, il faut passer par un commercial.

**Petit BamBou Pro :** à partir de **41,70 €/licence** (5 à 100 salariés), ou « à partir de 50 €/an/salarié, dégressif », selon la source. Environ 200 entreprises clientes fin 2023, dont 90 % en France.

**Grands comptes (estimations Vendr, surtout US) :** 8 à 35 $/salarié/an. Plus l'entreprise est grande, plus le prix baisse.

**Le modèle :** on paie **par place achetée**, que les salariés utilisent l'app ou non. Ce n'est pas par salarié actif.

---

## 7. Règles App Store et Google Play (le point sensible)

**Ce que disent les textes :**
- **Apple 3.1.1** interdit de débloquer du contenu avec « license keys… QR codes » hors achat intégré.
- **3.1.3(c) « Enterprise Services »** autorise les accès payés par une entreprise, mais seulement si l'app est « only sold directly… to organizations ». Quieto vend aussi au grand public, donc ça ne s'applique pas à la lettre.
- **La base qui marche pour Quieto est 3.1.3(b) « Multiplatform Services ».** Le salarié accède à un abonnement acheté ailleurs, et c'est autorisé tant que **le même Premium reste en vente par achat intégré dans l'app**. C'est déjà le cas.

**Les refus connus :**
- Un simple champ « code promo » qui débloque Premium : rejeté.
- Des « Partner Codes » pour entreprises : rejetés en février 2026, puis débloqués après explications.
- Un SaaS B2B : rejeté, puis accepté après appel.

**À faire, comme Calm et Headspace :**
- Appeler ça **« Accès offert par mon entreprise »**, **jamais « code promo »**.
- Lier l'accès à **une entreprise et à un compte vérifié**.
- **Ne montrer aucun prix B2B ni bouton « Offrir Quieto à mon entreprise » dans l'app** (hors USA). La vente aux entreprises passe par le site et les e-mails.
- Dans les notes pour la review Apple, expliquer le contrat B2B et fournir **une entreprise de démo et un e-mail de démo**.
- Garder le paywall d'achat intégré pour tout le monde.
- Les cartes cadeaux grand public restent sur le web (Calm et Headspace font pareil).

**Google Play :** l'app peut donner accès à du contenu « paid for somewhere else ». Aucun texte ne parle du B2B, mais Calm et Headspace font exactement ça sur Android.

---

## 8. La technique (Quieto : Flutter + Firebase + RevenueCat)

**Débloquer Premium :**
- On utilise un **« granted entitlement » RevenueCat**, déclenché par une Cloud Function avec la clé secrète.
- API v1 : `POST /v1/subscribers/{uid}/entitlements/premium/promotional` avec `end_time_ms` = date de fin du contrat.
- API v2 : `actions/grant_entitlement` avec `expires_at`. ⚠️ Il faut l'ID interne de l'entitlement (`entl…`), pas le nom `premium`.
- Retirer l'accès : `revoke_promotionals`.

**Ce qu'il faut savoir sur ces accès offerts :**
- Ils ne touchent **jamais** à un abonnement App Store ou Play : ni résiliation ni remboursement. Les deux coexistent.
- Dans le SDK Flutter, `store == Store.promotional`.
- Ils ne comptent pas dans les « Active Subscribers » de RevenueCat.
- Ils sont gratuits côté facturation RevenueCat (déduction, pas confirmé noir sur blanc).

**Point de vigilance :**
- L'accès offert est attaché au `app_user_id`. Chez Quieto, c'est déjà l'UID Firebase (`Purchases.logIn(uid)` dans `main.dart` et `auth_service.dart`).
- Mais un compte anonyme se perd en changeant de téléphone. **Il faut sans doute exiger un compte connecté (Apple/Google) avant d'activer l'avantage**, comme Calm et Headspace.

**Salarié déjà abonné :**
- On le détecte avec `customerInfo.subscriptionsByProductIdentifier` : un abonnement `isActive && willRenew` sur `appStore` ou `playStore`.
- On affiche alors un message et un bouton vers `managementURL` (écran de gestion d'abonnement d'Apple).

**Vérification de l'e-mail pro :**
- **Ne pas** utiliser le lien de connexion par e-mail de Firebase : il ajouterait l'e-mail pro comme moyen de connexion au compte, et le salarié le perd en partant.
- Mieux : un **code à 6 chiffres** envoyé par une Cloud Function.

**Contre les abus :**
- Firebase App Check sur la fonction.
- Limite d'essais par compte.
- Un seul avantage actif par compte.
- Plafond de places par entreprise.

**Ce qu'il ne faut pas utiliser :**
- **Les codes d'offre Apple** : interdits à la vente par le contrat Apple (§3.13), iOS seulement, impossibles à révoquer, et ils peuvent se transformer en abonnement payant.
- **RevenueCat Web Billing** : « B2B isn't supported ».

**Faire payer l'entreprise :** Stripe, séparé de l'app.
- Paiement par carte avec un nombre de places au choix (`adjustable_quantity`).
- Ou facture et virement (`send_invoice`).

---

## 9. France : canaux de vente, fiscalité, arguments

**Les canaux :**
- **Les CSE sont un canal énorme en France.** Headspace renvoie même vers le CSE dans son aide en français. Petit BamBou est présent sur HelloCSE (−10 %), PLUSDE (sur devis) et Pluxee (le salarié convertit son solde cadeau en code). Leeto propose un formulaire pour devenir partenaire (200 000 salariés).
- **Les mutuelles :**
  - Harmonie Mutuelle / VYV revend Moodwork à −30 %.
  - GSMC travaille avec Holivia et a offert Petit BamBou à ses adhérents.
  - AGIPI offre Teale avec un code commun.
- **L'argument légal :** l'article **L4121-1 du Code du travail** oblige l'employeur à protéger la santé **mentale** de ses salariés. L'INRS et l'OMS disent qu'une app vient **en complément** des actions sur l'organisation du travail, pas à leur place. C'est donc comme ça qu'il faut la présenter.
- **Le bon moment :** la santé mentale est **grande cause nationale**, prolongée en 2026.

**Cotisations sociales (URSSAF) :** [NON VÉRIFIÉ, aucun texte ne vise les apps de bien-être]
- Si l'employeur paie un abonnement individuel, c'est probablement un avantage en nature, donc soumis à cotisations.
- Si c'est le **CSE** qui le finance (activités sociales et culturelles), c'est exonéré sous conditions : ouvert à tous, sans lien avec la performance.
- **À faire confirmer par un comptable**, ou par une demande officielle à l'URSSAF (« rescrit »).

**Les chiffres utilisables dans le pitch (sourcés) :**
- **Malakoff Humanis 2026 :**
  - 32 % des salariés du privé ont eu au moins un arrêt en 2025 ;
  - taux d'absentéisme de 4,3 % ;
  - troubles psychologiques = **37,8 % des arrêts de plus de 30 jours**.
- **WTW 2025 :** absentéisme de 5,1 %, risques psychosociaux = 36 % des arrêts longs, **plus de 120 Md€/an** pour les entreprises.
- **Ayming 2026 :** coût caché moyen de **4 000 € par salarié**.
- **Asterès / MGEN 2025 :** la santé mentale au travail coûte **24,7 Md€/an**, dont 31 % payés par les employeurs.
- **Empreinte Humaine juin 2026 :** **50 % des salariés en détresse psychologique**, 32 % à risque de burn-out, 11 % à risque sévère. Le risque de burn-out sévère est **2 fois plus élevé qu'avant le Covid**. C'est sans doute de là que vient ton « ×2 ».
- **Essai Headspace en entreprise (JAMA Network Open 2025, 1 458 personnes) :** effet **fort sur le stress**, effet faible à modéré sur le burn-out. L'étude est financée par Headspace.

**À ne PAS dire :**
- **« Burn-out divisés par 2 »** : aucune source.
- **« Moins d'absentéisme grâce à l'app »** : non démontré. L'essai de Calm n'a trouvé aucune différence, et deux méta-analyses non plus.
- **« +productivité »** : effet faible et fragile.
- **« 4 $ rapportés pour 1 $ investi » (OMS)** : ce chiffre concerne le *traitement* de la dépression, pas les apps.

---

## 10. Pistes pour Quieto (proposition, rien n'est codé)

Le modèle de Calm, avec en plus la vérification par e-mail de Headspace :

1. **Profil → section « Mon compte » → « Accès offert par mon entreprise »**.
2. Le salarié tape le nom de son entreprise, avec autocomplétion.
3. Ce qui est demandé dépend de ce que l'entreprise a choisi :
   - **e-mail pro + code à 6 chiffres** reçu par mail, pour les PME ;
   - ou **code d'entreprise** plafonné en places, pour les TPE et les CSE.
4. Une Cloud Function vérifie, enregistre le membre dans Firestore (`entreprises/{id}/membres/{uid}`), puis débloque Premium dans RevenueCat jusqu'à la fin du contrat.
5. Écran « Premium offert par {entreprise} ». Si un abonnement perso est actif, un message et un bouton pour le résilier.
6. **Départ ou fin de contrat :** accès retiré à la fin du mois, puis écran « Continuer avec Quieto » avec une offre.

**Côté entreprise, en V1, pas de portail :**
- Tu crées l'entreprise à la main (nom, méthode, domaine e-mail, places, date de fin).
- Tu envoies un rapport mensuel de totaux anonymes, rien sous 10 personnes.
- L'entreprise paie par facture ou lien Stripe.
- Le portail viendra plus tard.

**Décisions à prendre avant de coder :**
- La méthode d'accès pour la V1 : e-mail pro + code, code d'entreprise, ou les deux.
- Faut-il un compte connecté obligatoire ?
- Le prix et la cible de départ : PME, CSE ou mutuelles.

---

## 11. Ce qui a été construit (23/09), paiement par Whop

Paul a d'abord choisi Stripe, puis **Whop** pour le paiement. Le code n'est ni déployé ni publié.

**Whop, les faits (docs.whop.com, relevés le 23/09/2026) :**
- **Frais :**
  - prélèvement SEPA : 1 % + 0,30 € ;
  - carte : 2,7 % + 0,30 $, plus 1,5 % si la carte est étrangère et 1 % en cas de conversion de devise ;
  - options payantes : Billing +0,5 %, taxes +2 % ;
  - virement vers ta banque : selon le pays.
  
  C'est plus cher que Stripe (~1 %), mais bien en dessous des 15 % des stores.
- **Abonnements :** mensuels et annuels, SEPA accepté y compris sur les renouvellements.
- **TVA :** Whop est « merchant of record » pour la TVA européenne. C'est lui qui la facture et la déclare.
- **Pas de quantité sur la page de paiement.** On passe par des forfaits par taille : 10, 25, 50 et 100 personnes, chacun en mensuel et en annuel. Chaque forfait porte la métadonnée `places`, posée via l'API Whop.
- **Nom de l'entreprise :** demandé par une question avant le paiement (« Ask questions before checkout »). La réponse arrive dans `custom_field_responses`.
- **Webhooks :**
  - format Standard Webhooks (HMAC-SHA256, secret `ws_…`) ;
  - événements `membership.activated`, `membership.deactivated`, `payment.succeeded`… ;
  - Whop réessaie pendant environ 3 jours et n'assure pas l'ordre des envois, d'où la relecture de l'abonnement (`GET /api/v1/memberships/{id}`) à chaque webhook.
- **Espace client :** l'acheteur gère son abonnement (résiliation, changement de forfait) via `manage_url`.

**Serveur** (`quieto-backend/functions/index.js`, section « ACCÈS ENTREPRISE ») :
- `whop` (webhook) : met à jour `entreprises/{mem_…}`. À la première activation, il crée le code (ex. `ACME-7K2P`) et l'envoie à la RH par e-mail via Resend, avec un texte à transférer.
- `accesEntreprise` (appelée par l'app) :
  - exige un compte Apple ou Google ;
  - quotas de 30 essais par jour par IP et 10 par compte ;
  - montre d'abord un aperçu du nom, puis sur confirmation : une place prise (transaction) et Premium accordé via RevenueCat (`POST /v1/subscribers/{uid}/entitlements/premium/promotional`) jusqu'à la fin de la période payée + 10 jours.
- `synchroniserAbonnement` : reprolonge le salarié à chaque lancement si l'entreprise a payé une nouvelle période. Il n'y a aucun traitement de masse : une entreprise qui ne paie plus voit l'accès de ses salariés s'éteindre tout seul.
- `supprimerDonnees` : libère la place du salarié.
- Outil admin `quieto-backend/scripts/entreprise.js` : `liste`, `creer`, `prolonger`, `places`, `renommer`, `membres`, `retirer`, `desactiver`. Il sert pour la démo App Review et les CSE qui paient par virement.

**App :**
- Profil → « 🏢 Accès offert par mon entreprise » (`widgets/acces_entreprise_sheet.dart`). Le parcours : connexion si besoin → code → « Premium offert par X » → Activer.
- Si un abonnement perso est actif, un avertissement s'affiche avec un lien « Gérer mon abonnement ».
- La carte Premium du profil affiche « Premium offert par X ».
- Événements Vigie : `entreprise_code`, `entreprise_activee`, `entreprise_activation_echec`.

**Site :** site à part `~/Desktop/dev/quieto-entreprise-site/` (DA Quieto ; la page d abord mise dans cofonde-site a été retirée) présente :
- le pitch, avec des chiffres sourcés ;
- les 3 étapes ;
- la confidentialité ;
- les tarifs, avec un bouton mensuel/annuel ;
- une FAQ.

Les boutons « Choisir » ouvrent un e-mail tant que les liens Whop ne sont pas collés (`LIEN_WHOP_…`).

**Prix proposés (à valider par Paul) :**

| Forfait | Mensuel | Annuel |
|---|---|---|
| 10 personnes | 39 € HT | 390 € HT |
| 25 personnes | 89 € HT | 890 € HT |
| 50 personnes | 169 € HT | 1 690 € HT |
| 100 personnes | 299 € HT | 2 990 € HT |

L'annuel correspond à 2 mois offerts. Ça revient à 2,99-3,90 €/personne/mois, contre 41,70-50 €/an chez Petit BamBou et environ 54 €/an chez Headspace.

**Reste à faire :**
- **Paul :**
  - compte Whop (identité, IBAN) ;
  - produit « Quieto Entreprise » avec la question « Nom de votre entreprise » ;
  - 8 forfaits ;
  - clé API (droits `member:basic:read` + `member:email:read`) ;
  - webhook vers `https://…/whop` avec les événements membership.* et payment.succeeded.
- **Moi :**
  - poser `places` sur chaque forfait via l'API ;
  - ranger les secrets `WHOP_API_KEY` et `WHOP_WEBHOOK_SECRET` ;
  - coller les liens dans la page ;
  - déployer ;
  - créer l'entreprise de démo pour App Review.
- **⚠️ Tant que les secrets Whop n'existent pas,** ne déployer que `accesEntreprise`, `synchroniserAbonnement` et `supprimerDonnees`. Un `firebase deploy --only functions` complet réclamerait les secrets Whop.
- **À vérifier au premier essai réel :**
  - que la clé `RC_API_KEY` accepte bien l'API v1 « promotional » ;
  - quelle forme de clé la signature Whop utilise : le code accepte les 3 variantes et note dans les logs laquelle a marché.

### Sources principales
- **Calm :**
  - support.calm.com/hc/en-us/articles/14481312650267 (parcours dans l'app)
  - …/360055261934 (salarié déjà abonné)
  - …/14980789382811 (départ)
  - …/20074535685915 (stats, seuil de 10)
  - …/360038432493 (facturation)
  - guide admin : info.calm.com/rs/541-LYF-023/images/Calm_Business_Partner_Portal_Administrator_Guide.pdf
  - health.calm.com/calm-for-organizations
  - api.calm.com/stripe-price-catalog/price?plan=b2b_selfserve_1y
- **Headspace :**
  - help.headspace.com/hc/en-us/articles/360000220608 (inscription)
  - …/360048571313 (e-mail d'activation)
  - …/360048571933 (départ)
  - …/28123374670747 (stats)
  - …/1260805591470 (SSO dans l'app)
  - organizations.headspace.com/small-business
  - work.headspace.com/texas811/member-enroll, work.headspace.com/v3/mayoclinic/member-enroll/verify (pages de vérification)
  - rachat par Sword : globenewswire.com, 16/09/2026
  - part du B2B en 2021 : bhbusiness.com, 26/10/2021
- **France :**
  - support.petitbambou.com/hc/fr/articles/4406980400531, …/4406969380755
  - jaimelesstartups.fr (Petit BamBou Pro)
  - lejournaldesentreprises.com (200 clients)
  - moka.care/faq, teale (API Zendesk), holivia.fr
  - hellocse.fr, plusde.com, pluxee.fr
  - harmonie-mutuelle.fr
  - Légifrance L4121-1, INRS, cnil.fr
- **Stores et technique :**
  - developer.apple.com/app-store/review/guidelines
  - forums Apple : threads 817176, 724032, 736622, 825551
  - support.google.com/googleplay/android-developer/answer/10281818
  - revenuecat.com/docs/api-v1/entitlements, /api-v2/customer, /dashboard-and-metrics/customer-profile
- **Chiffres :**
  - Malakoff Humanis (newsroom, 30/06/2026), WTW (editions-tissot.fr), Ayming, MGEN/Asterès, Empreinte Humaine (franceinfo)
  - pmc.ncbi.nlm.nih.gov PMC11733700 (Headspace), PMC9557765 (Calm), PMC10172073 (méta-analyse)
