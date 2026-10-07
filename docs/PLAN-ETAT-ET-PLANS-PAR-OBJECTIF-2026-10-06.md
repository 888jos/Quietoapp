# Quieto : état de l'app, audit et planification des plans par objectif

> Rédigé le 06/10/2026 sur la branche `refactor/mvvm`, en lecture seule : aucun code n'a été modifié.
> Ce document couvre l'app iOS native (`app/ios/QuietoNative`), le backend Supabase (`supabase/`), le proxy Louane encore sur Firebase (`backend/functions`) et le dashboard (`dashboard/`).
> Les chemins Swift sont relatifs à `app/ios/QuietoNative/Sources/QuietoNative/`.

---

## 1. Vue d'ensemble : où en est l'app

### 1.1 Deux apps en parallèle

| | App en production | Nouvelle app (cette branche) |
|---|---|---|
| Techno | Flutter (`app/lib`) | Swift/SwiftUI natif, MVVM (`app/ios/QuietoNative`) |
| Version | 1.0.28+39, envoyée aux stores le 28/09 | non publiée, bundle de migration `com.quietoapp.app.native` |
| Backend | Firebase (Firestore, Functions, RevenueCat) | Supabase (Postgres + RLS, Edge Functions), Superwall |
| Modèle éco | essai + paywall souple, Louane gratuite | **hard paywall** Superwall (essai 7 j) |
| IA Louane | Cloud Function `louane` (GPT-5.6 Luna) | même fonction Firebase, appelée via `supabase/functions/louane-proxy` |

### 1.2 Contenu de l'app native (≈ 9 500 lignes Swift, 88 tests)

| Domaine | État |
|---|---|
| Onboarding : 41 écrans en 7 actes, reprise après fermeture | Fonctionne en français. Pas traduit, une fuite de données sensibles, une boucle après une crise (voir §2) |
| Hard paywall Superwall + restaurer + gérer l'abonnement | Logique en place. Clés `REPLACE_…`, bundle de migration, pas de liens légaux sur le mur |
| Accueil | **Affiche des données de démo** (« Léa », faux programme) |
| Catalogue : 94 séances (81 guidées + 13 respirations), 15 situations, 14 thèmes, recherche, favoris | Fini côté app. Favoris jamais relus du serveur |
| Narration audio | **0 audio enregistré sur 81** : tout est lu par la voix de synthèse Apple. Scripts FR écrits (`Narration/scripts/fr`) |
| Téléchargements hors ligne | Inactif tant qu'il n'y a pas d'audio |
| Lecteur : mini, plein écran, minuterie, écran verrouillé | Fini, quelques bugs d'ambiance |
| Respirations (13 rythmes) | Fini |
| Ambiances | 11 sur 16 présentes dans le bundle |
| Programme 7 jours | Partiel : pas de déblocage par jour, rythme cosmétique, rien après le jour 7 |
| Louane : chat, historique, mémoire | Partiel : historique et mémoire serveur cassés (C1), ne connaît ni le programme ni le nouveau catalogue |
| Gamification : série, 38 badges, calendrier | Fini et testé |
| HealthKit | Écriture OK. Lecture demandée mais jamais utilisée |
| Rappels + rappel de fin d'essai | Fini (textes non traduits) |
| Profil : export, suppression de compte | Partiel : pas de confirmation, pas de révocation Apple, inaccessible quand l'app est verrouillée |
| Réglages accessibilité (réduire les animations, texte plus grand) | Enregistrés, jamais appliqués |
| Analytics : Amplitude + `analytics_events` | Amplitude OK, insertions Supabase refusées (C1) |

### 1.3 Build et tests (lancés le 06/10 sur simulateur iPhone 17)

- **Le build compile.**
- **83 tests sur 88 passent.** Les 5 échecs viennent du même test, `testEverySupportedLanguageHasTheSameLocalizationKeys` : il manque des titres de séances en de, en, es, ja et ko.

### 1.4 Backend Supabase

- **Tables `public` :** 15, toutes avec RLS « propriétaire » (`user_id = jwt.sub`, en `text`).
- **Schéma `private` :** registre des abonnements et admins du dashboard.
- **Accès Premium :** une seule source de vérité, `apply_store_subscription()`. Elle est alimentée par `subscription-sync` (JWS StoreKit), `superwall-webhook` (Svix) et `revenuecat-webhook` (legacy).
- **Points sains :** pas de secret dans le dépôt ; webhooks signés et vérifiés en temps constant ; `search_path` fixé sur toutes les fonctions SECURITY DEFINER ; bucket audio privé.

---

## 2. Audit : problèmes à corriger

Les points sont classés par sévérité et vérifiés dans le code.

### 🔴 Critique : bloque la production

| # | Problème | Où | Effet |
|---|---|---|---|
| C1 | **L'identifiant utilisateur part en MAJUSCULES** (`uuidString`) alors que la RLS compare le texte avec `jwt.sub`, en minuscules | `Data/Backend/QuietoSupabaseRepository.swift` (≈16 endroits, ex. :236, :264), `QuietoSupabaseService.swift:166, :192` | Les écritures (profil, progression, programme, préférences, onboarding, Louane, analytics) sont refusées et les lectures reviennent vides. **En silence**, à cause des `try?`. Seul `QuietoPracticeSync.swift:27` fait `.lowercased()`. |
| C2 | **L'accueil affiche des données de démo** | `HomeViewModel.swift:16` démarre sur `.preview` ; `HomeView` ne charge qu'au tirer-pour-rafraîchir | Tout le monde voit « Bonsoir Léa », un faux programme 2/7 et « Étape 3 sur 7 » (en dur, `HomeComponents.swift:22`). |
| C3 | **La réponse à la question suicide fuit vers les analytics** | `OnboardingViewModel.swift:122-161` | L'événement `onboarding_step` envoie `step=crisisSupport` à Amplitude (serveurs US) et à Supabase. Le `total` d'écrans trahit aussi la réponse. Cela contredit « Ta réponse reste sur ton iPhone ». |
| C4 | **Configuration de publication** | `project.yml` | Bundle `com.quietoapp.app.native` : les abonnés actuels seraient bloqués par le hard paywall. Clés Superwall et Supabase en `REPLACE_…`. Équipe Apple changée sans mise à jour du README. |

### 🟠 Élevée

**App iOS**
- **E1.** Le paywall strict recouvre tout. Une personne expirée ne peut ni supprimer son compte (règle 5.1.1(v)), ni lire les CGU ou la confidentialité (3.1.2). Il manque aussi « Gérer l'abonnement ». → Ajouter ces liens dans `HardPaywallView`.
- **E2.** Sign in with Apple : pas de révocation du jeton à la suppression de compte (exigé par Apple).
- **E3.** Une simple erreur réseau au démarrage peut remplacer un compte Apple par un compte anonyme (`QuietoSupabaseService.swift:94-104`).
- **E4.** La réponse de sécurité, le stress et le sommeil sont stockés en clair dans `UserDefaults` et partent dans la sauvegarde iCloud.
- **E5.** La mémoire Louane « supprimée » depuis le Profil reste en local et part encore à l'IA à chaque message.
- **E6.** L'onboarding, le paywall et l'écran 3114 ne sont pas traduits. Le numéro de crise est français quelle que soit la région.
- **E7.** **183 fichiers non suivis par git**, dont `AppContainer`, toute la gamification, les ViewModels, les tests, 3 migrations et les `.m4a`. Un commit partiel ne compile pas, et le travail risque d'être perdu.

**Backend**
- **B-E1.** `is_dashboard_admin()` se fie au claim `email` du jeton sans vérifier l'émetteur ni `email_verified`. Un jeton Firebase portant l'email de l'admin pourrait lire les métriques ; cela dépend des réglages Firebase. → Lire l'email confirmé dans `auth.users` et exiger l'émetteur Supabase.
- **B-E2.** Les transactions Apple (JWS) sont transférables à l'infini : `p_transfer = true`, sans contrôle d'`appAccountToken` ni d'âge. Un abonnement peut ainsi servir à plusieurs comptes. → Transférer seulement si `appAccountToken == user.id` ou si la transaction n'est rattachée à personne.

### 🟡 Moyenne

**Backend**
- **Sandbox :** les achats Sandbox et TestFlight donnent Premium en production (pas de filtre `environment`).
- **Suppression RGPD incomplète :** il reste des données Firestore (`securite/{uid}` = horodatage d'alerte 3114), Firebase Auth, Superwall, Amplitude, RevenueCat, et `store_subscriptions.raw`.
- **Rétention :** aucune purge (`analytics_events`, `louane_messages`…) ; les comptes anonymes s'accumulent.
- **Coût Louane :** pas de limite de débit par utilisateur sur `louane-proxy`. Un 504 du proxy (30 s) laisse quand même tourner la fonction Firebase, et donc la facture OpenAI.
- **Analytics falsifiables :** tout compte anonyme peut écrire des événements, et les `jsonb` ne sont pas bornés.

**Audio**
- Lancer une séance coupe l'ambiance choisie.
- Une ambiance seule ne gère ni les interruptions ni la déconnexion des AirPods.
- Le mini-lecteur reste visible et inactif après un verrouillage.

**Synchronisation**
- Pas de file d'attente hors ligne : les séances terminées hors ligne et la synchronisation de l'onboarding sont tentées une seule fois.
- `serverPremium` n'est pas mémorisé : les accès B2B et legacy sont verrouillés à chaque démarrage à froid.
- Pas d'écoute de `Transaction.updates` : une expiration ou un remboursement n'est pris en compte qu'en revenant au premier plan.

**Profil**
- La suppression de compte part en un seul tap, sans confirmation.
- La déconnexion efface les données locales avant l'appel réseau.
- L'effacement local supprime aussi la complétion de l'onboarding.

**Louane**
- Une réponse en cours peut être rangée dans une autre conversation.
- Aucune détection de crise locale dans le chat.
- Après un texte de crise saisi à l'onboarding, « Continuer » renvoie à la respiration, ce qui crée une boucle.

**HealthKit**
- La lecture est demandée mais jamais utilisée, alors que la description d'usage promet d'« adapter tes séances ».

### ⚪ Basse : à traiter au fil de l'eau

- **Éléments factices :** la cloche de l'accueil ne fait rien, « Adapter mon rythme » ne fait rien, « Écoutée hier » est écrit en dur.
- **Bouton pause du Programme :** il relance la lecture au lieu de mettre en pause.
- **Validation des fichiers :** pas de contrôle du type des fichiers téléchargés.
- **URL signées :** elles expirent au bout de 15 min, ce qui posera problème pour les séances de 20 min une fois l'audio publié.
- **Architecture :** quelques entorses aux règles du README (services qui s'appellent entre eux, vues qui appellent un service).
- **Amplitude :** la même clé sert en debug et en prod, et `PrivacyInfo.xcprivacy` ne la déclare pas.
- **Tests absents** sur l'abonnement, la casse de l'identifiant, la fuite de l'étape de crise, les téléchargements et le chargement de l'accueil.

### Ce qui manque au produit

1. **L'audio des séances.** C'est le manque le plus visible pour l'utilisateur : une app de méditation payante avec la voix de synthèse Apple sur 81 séances.
2. **La suite après le jour 7 :** pas de vrai programme, ni de déblocage par jour, ni de rythme effectif.
3. **Louane alignée sur la nouvelle app :** elle reçoit `parcours: null`, ne connaît que l'ancien catalogue de 35 séances (63 nouvelles lui sont inconnues) et pousse un signal `[PARCOURS]` que l'app ignore.
4. **Les traductions** (onboarding et paywall) avant toute sortie hors France.

---

## 3. Plans par objectif : planification (pas encore de développement)

### 3.1 Ce qui existe déjà et ce qu'on garde

- **Objectif déjà demandé :** l'onboarding pose la question `goal` (« Dans 30 jours, tu aimerais… ») avec 5 réponses : `sleep`, `calm`, `anxiety`, `focus`, `habit`.
- **Le catalogue est déjà étiqueté par pilier :**

| Pilier | Séances | Objectifs (`QuietoGoal`) |
|---|---|---|
| stress | 34 | calm, relax |
| emotions | 25 | emotion, energy, kindness |
| thoughts | 21 | focus, perspective |
| sleep | 14 | sleep |

- **Le moteur à remplacer est `OnboardingPlanBuilder`** (`Features/Onboarding/OnboardingModels.swift:173-238`). Il a trois défauts :
  - il n'utilise que 5 réponses sur 12 ;
  - **son ordre est instable** en cas d'égalité (tri sur un `Dictionary`) ;
  - il pioche dans l'ordre du fichier catalogue. Résultat : un plan « sommeil » à 5 min contient seulement **2 séances sommeil sur 7**, et un plan « anxiété » contient « Avant une présentation ».
- **La structure de données est réutilisable :** les tables `programs` et `program_steps` existent, avec `louane_note`, `raw_program` jsonb et le statut `abandoned` (jamais utilisé).

### 3.2 bis — Décision du 06/10 (soir) : 6 plans, plus longs

Retour : un nombre **pair** de plans (4 ou 6) et des plans **longs**, parce que la durée améliore la rétention. La recommandation ci-dessous passe donc à **6 plans de 28 jours** (4 semaines). La semaine Découverte reste un module d'introduction pour les débutants et ne compte pas comme un plan.

**Les 6 plans :**
1. Mieux dormir
2. Apaiser l'anxiété
3. Souffler face au stress
4. Apaiser le mental
5. Être bien avec soi
6. **Des relations plus apaisées** (nouveau)

**Pourquoi « Relations » en 6ᵉ plutôt qu'« Énergie et matin » :**
- Il y a déjà 10 séances dédiées, plus 2 respirations.
- Il répond directement aux sources de stress « couple » et « famille » de l'onboarding.
- Peu de concurrents français le proposent.

**28 jours sans contenu inutile :**
- 5 séances principales par semaine.
- 2 jours « libres » par semaine : une respiration ou une ambiance.
- Une séance clé peut revenir dans la même semaine (répéter fait partie de l'apprentissage).

**Ce qu'il faut en contenu :** environ 18 à 20 séances uniques par plan, dont une partie reprise. À la fin, on enchaîne sur un **niveau 2** du même plan, ce qui donne 8 semaines en continu.

**Si on préfère démarrer à 4 :** commencer par **Mieux dormir, Souffler face au stress, Apaiser le mental et Être bien avec soi**, les mieux couverts aujourd'hui. Puis ajouter **Anxiété** et **Relations** une fois leurs séances écrites et enregistrées (voir 3.6). Environ 25 à 30 scripts au total sont à produire pour les 6 plans de 28 jours.

### 3.2 Recommandation initiale : 5 plans + une semaine « Découverte »

L'objectif choisi détermine le plan. L'expérience détermine si l'on commence par la semaine Découverte.

| # | Plan | Promesse (sans allégation médicale) | Pilier | Séances disponibles | Couverture |
|---|---|---|---|---|---|
| 1 | **Mieux dormir** | Retrouver des soirées et des nuits plus calmes | sleep | 14 + respirations du soir | 🟠 manque du court (≤5 min) |
| 2 | **Apaiser l'anxiété** | Traverser les vagues d'angoisse avec des outils simples | stress (sous-ensemble) | ≈ 10 pertinentes | 🔴 contenu dédié insuffisant |
| 3 | **Souffler face au stress** | Décompresser au quotidien et au travail | stress | 34 | 🟢 |
| 4 | **Apaiser le mental** | Moins ruminer, mieux se concentrer | thoughts | 21 | 🟢 |
| 5 | **Être bien avec soi** | Accueillir ses émotions, être plus doux avec soi | emotions | 25 | 🟡 manque du court |
| (0) | **Semaine Découverte** | Apprendre les bases en 7 jours | — | 9 séances Découverte + respirations | 🟢 |

**Pourquoi 5 et pas 6 :**
- **`habit` n'est pas un objectif de contenu.** C'est un profil de débutant : il est mieux servi par la semaine Découverte, suivie du plan du deuxième centre d'intérêt.
- **Un 6ᵉ plan « Énergie et matin »** (8 + 7 séances) serait trop mince aujourd'hui. On peut le garder pour une V2.
- **Calm et anxiété sont séparés volontairement.** Le stress du quotidien et l'angoisse ne demandent pas le même accompagnement. L'anxiété est aussi le mot-clé ASO n°1 (« Anxiété & Sommeil » dans le nom de l'app).

**Contenu de départ proposé par plan** (ids existants, ordre à affiner) :

1. **Mieux dormir**
   - Séances : `screen_off`, `express_4`, `sleep_3`, `sleep_1`, `sleep_cognitive_shuffle`, `sleep_5`, `sleep_4`, `middle_of_night`, `new_body_scan_sleep`, `sleep_2`, `night_sky`, `night_watch`.
   - Respirations : `stress_2` (4-7-8), `breath_sleep_descent`.
   - Appui : `stress_5`, `new_long_exhale`.
2. **Apaiser l'anxiété**
   - Séances : `decouverte_3`, `breath_sigh`, `breathing_1`, `express_7`, `new_sensory_shelter`, `meditation_15`, `emotion_3`, `emo_uncertainty`, `new_safe_place`, `new_thoughts_on_clouds`, `rel_worry_for_someone`, `sunday_reset`.
   - Respiration : `new_long_exhale`.
3. **Souffler face au stress**
   - Séances : `express_5`, `between_calls`, `meditation_09`, `express_2`, `new_focus_reset`, `rel_before_hard_talk`, `express_1`, `express_8`, `after_work`, `commute_home`, `doorstep_pause`, `friday_release`, `stress_3`.
   - Respirations : `breathing_3`, `breath_sigh`.
4. **Apaiser le mental**
   - Séances : `discover_counting`, `decouverte_2`, `new_focus_reset`, `actualite_3`, `meditation_10`, `new_thoughts_on_clouds`, `decision_pause`, `creative_block`, `afternoon_reframe`, `meditation_06`, `discover_open_sitting`, `actualite_1`, `meditation_08`.
   - Respirations : `new_box_breathing`, `breathing_2`, `breath_counting`.
5. **Être bien avec soi**
   - Séances : `small_joy`, `meditation_05`, `discover_rain`, `emo_sadness`, `emo_anger`, `emo_inner_critic`, `morning_kind_start`, `emotion_1`, `work_impostor`, `gentle_recovery`, `rel_gratitude_someone`, `lonely_evening`, `emotion_4`, `emotion_5`.
   - Respiration : `breath_cooling`.

### 3.3 Structure d'un plan

- **Durée :** 21 jours en 3 phases d'une semaine.
  - **Comprendre :** séances courtes, bases et respiration clé du plan.
  - **Pratiquer :** cœur du thème, séances plus longues.
  - **Ancrer :** autonomie, moins de guidage, bilan.
- **Un jour, c'est :**
  - 1 séance principale ;
  - 1 « bonus » facultatif (respiration ou ambiance) ;
  - 1 mot de Louane (`program_steps.louane_note`).
- **Variante de durée selon la réponse `minutes` :**
  - chaque étape a une version courte et une version normale ;
  - quand le contenu court manque, la respiration du plan sert de version courte.
- **Déblocage :**
  - un jour se débloque à la date `started_at + (n−1)`, ou au plus tôt le lendemain de la séance précédente ;
  - un jour manqué ne pénalise pas : on reprend où on en était ;
  - le rythme (Doux / Régulier / Soutenu) espace réellement les jours et pilote les rappels.
- **Progression :** elle est comptée **uniquement sur les étapes du plan**, et non sur toute écoute passée comme aujourd'hui.
- **Mesure et bilan :**
  - le curseur stress 0-10 de l'onboarding sert de mesure au jour 0, au jour 7 et au jour 21 ;
  - le bilan final est montré par Louane ;
  - c'est aussi un argument de rétention et une base pour le dashboard.
- **Après le plan :**
  1. niveau 2 du même plan (V2), ou un autre plan recommandé ;
  2. ou « mode libre » : catalogue + séance du jour suggérée.
- **Changer de plan** depuis le Profil :
  - l'ancien passe à `abandoned` ;
  - la progression et les badges restent acquis ;
  - **un seul plan actif à la fois** (l'index unique existe déjà en base).

### 3.4 Comment l'onboarding détermine le plan

1. **La question `goal` devient le choix du plan.** Elle a 5 réponses alignées 1:1 sur les plans :
   - « Mieux dormir » ;
   - « Moins de moments d'angoisse » ;
   - « Mieux gérer le stress » ;
   - « Avoir l'esprit plus clair » ;
   - « Être plus en paix avec moi-même ».
   
   « Avoir pris l'habitude » disparaît de cette question : il devient la semaine Découverte, décidée par `experience`.
2. **Le score est déterministe** et remplace `OnboardingPlanBuilder` :
   - `goal` = +5 ;
   - `reasons` = +2 par réponse correspondante ;
   - `sleep` ≠ « je dors bien » = +1 au sommeil ;
   - `hardestTime` = night → +1 au sommeil.
   
   En cas d'égalité, l'ordre est **fixe** (ex. goal > sommeil > anxiété > stress > mental > soi). Le tout est testé par une matrice de cas.
3. **Les réponses aujourd'hui ignorées servent à personnaliser** :
   - `experience` (`never` ou `tried`) → ajoute la semaine Découverte ;
   - `minutes` → variante de durée ;
   - `moment` et `hardestTime` → heure du rappel et ordre des séances (sommeil le soir) ;
   - `stressSources` (travail, relations, actualité…) → 2 ou 3 jours « situation » insérés dans le plan (ex. `work_after_criticism`, `actualite_5`) ;
   - `blockers` (`time`) → rythme Doux proposé par défaut.
4. **L'écran `plan` devient une « révélation du plan » :**
   - plan recommandé + phrase « parce que tu as dit… » ;
   - lien « Ce n'est pas tout à fait ça ? » → 2 autres plans proposés selon le score.
   
   Le choix est ensuite envoyé à Superwall (attribut `plan_id`) pour adapter le paywall.
5. **Sécurité :**
   - si la question de sécurité est positive, l'écran 3114 reste prioritaire ;
   - le plan Anxiété garde un accès permanent au 3114 ;
   - **aucune donnée liée à la question de sécurité n'entre dans le score ni dans les analytics.**

### 3.5 Impacts techniques (pour le futur développement)

| Couche | Changement |
|---|---|
| **Modèle** | Nouveau `QuietoPlan` (`id`, `version`, `pillar`, `title`, `phases`, étapes avec variantes courte et normale, `louaneNote`). `PlanCatalog` statique dans l'app, **exporté en JSON** pour le backend (une seule source, comme `narration-fr.json`). |
| **Recommandation** | `PlanRecommender` pur et testé, qui remplace `OnboardingPlanBuilder`. |
| **Supabase** | Migration `programs` : `plan_id`, `plan_version`, `rhythm`, `variant`. Migration `program_steps` : `day_number`, `available_on`. Utiliser `abandoned` au changement de plan. |
| **Programme** | `ProgramViewModel` : déblocage par date, progression par étapes, rythme effectif, fin de plan et suite. |
| **Accueil** | Carte « Aujourd'hui dans ton plan » (jour N/21, séance du jour, bonus), qui remplace les données de démo (C2). |
| **Louane** | Remplir `parcours` (titre, jour, séance du jour faite, terminé), synchroniser `catalogue_seances.json` (94 séances), consigne par plan, et gérer ou supprimer le signal `[PARCOURS]`. |
| **Rappels** | Planifiés selon le rythme et le moment ; texte qui cite la séance du jour. |
| **Profil** | Section « Mon plan » : changer de plan, de rythme, recommencer. |
| **Analytics + dashboard** | Événements `plan_recommended`, `plan_chosen` (recommandé ou alternative), `plan_day_completed`, `plan_switched`, `plan_completed`. Rétention par plan. |
| **Tests** | Matrice réponses → plan, stabilité de l'ordre, déblocage par date et fuseau, reprise après des jours manqués. |

### 3.6 Contenu à produire

Il faut **environ 15 à 20 scripts** pour que chaque plan tienne ses 21 jours avec des variantes courtes :

- **Anxiété (priorité 1) :**
  - 5 à 6 séances : vague d'angoisse en 5 min, anxiété anticipatoire, inquiétude pour la santé, « ancrage 5-4-3-2-1 », après une crise, se rassurer la nuit ;
  - un mode « SOS » de 3 min accessible partout.
- **Sommeil :**
  - 3 séances courtes (≤5 min) : « je n'arrive pas à décrocher », « dernier souffle avant de dormir », « rendormissement rapide ».
- **Être bien avec soi :**
  - 3 séances de bienveillance courtes (3-5 min).
- **Stress :**
  - études (0 séance aujourd'hui) et argent (0) : 1 ou 2 séances chacun, pour coller aux `stressSources`.
- **Bilans :**
  - 3 courtes séances de bilan (fin de semaine 1, 2 et 3), réutilisables par tous les plans.
- **Audio :** les séances des plans sont les premières à enregistrer. **L'enregistrement audio des plans doit précéder leur lancement.**

### 3.7 Ordre de marche proposé

| Phase | Contenu | Pourquoi d'abord |
|---|---|---|
| **0. Stabiliser** | C1-C4, E1-E7, B-E1, B-E2, Sandbox. Commit propre du refactor. Correction du test de localisation. | Sans C1, aucun plan ne peut être sauvegardé côté serveur ; sans C2, l'accueil ment. |
| **1. Socle plans** | Modèle `QuietoPlan`, `PlanRecommender`, migration Supabase, programme avec déblocage et rythme, carte d'accueil. Les 5 plans sont d'abord remplis avec le contenu existant. | Livrable testable sans nouveau contenu. |
| **2. Onboarding** | Nouvelle question objectif, révélation du plan avec alternatives, attribut Superwall, traductions. | Lien direct avec la conversion. |
| **3. Louane** | Contexte du plan, catalogue synchronisé, mot du jour, bilan de fin. | Louane est la meilleure surface de conversion (journal : 4,5 %). |
| **4. Contenu et audio** | Les 15-20 nouveaux scripts, puis l'enregistrement en commençant par les séances des plans. | Plus long, peut démarrer en parallèle de la phase 1. |
| **5. Suite** | Niveaux 2, plan « Énergie et matin », dashboard par plan. | Après mesure de la rétention. |

### 3.8 Décisions à prendre

1. **Nombre de plans :** 5 + Découverte (recommandé) ou 6 avec « Énergie et matin » ?
2. **Durée :** 21 jours (recommandé), 14 ou 28 ?
3. **Déblocage :** un jour par jour (recommandé, structure le rythme) ou tout accessible ?
4. **Un seul plan actif** (recommandé) ou plusieurs en parallèle ?
5. **Plans écrits à la main** (recommandé : stable, testable, sans coût IA) ou générés par Louane comme dans l'app Flutter (`genererParcours`) ?
6. **Wording « anxiété » :** valider avec un regard juridique la limite entre bien-être et dispositif médical (règlement UE 2017/745) avant de promettre un résultat sur l'angoisse.
