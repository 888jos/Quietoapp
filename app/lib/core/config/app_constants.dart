abstract final class AppConstants {
  // ── App ──────────────────────────────────────────────
  static const appName = 'Quieto';
  // ⚠️ À METTRE À JOUR EN MÊME TEMPS QUE pubspec.yaml (version: x.y.z+n).
  // Sert à la Vigie : comparer le funnel d'une version à l'autre.
  // (Resté à 1.0.25 dans les builds 1.0.26, 1.0.27 et 1.0.28 : ces trois
  // versions se présentent comme « 1.0.25 » dans la Vigie. Depuis le 28/09,
  // tool/build-release.sh refuse de builder si les deux ne concordent pas.)
  static const appVersion = '1.0.28';

  // ── Support ──────────────────────────────────────────
  // Adresse affichée dans « Nous contacter » (profil).
  static const supportEmail = 'contact@cofonde.com';

  // ── RevenueCat ───────────────────────────────────────
  static const entitlementPremium = 'premium';

  // ── SharedPreferences keys ───────────────────────────
  static const prefOnboardingDone = 'onboarding_done';
  static const prefOnboardingAnswers = 'onboarding_answers';
  static const prefSessionProgress = 'session_progress';
  static const prefUserFirstName = 'user_first_name';
  static const prefIsPremium = 'is_premium';
  // Mémoire de Louane : ce qu'elle retient de l'utilisateur entre les sessions.
  static const prefLouaneMemoire = 'louane_memoire';
  // Quotas Louane (jamais affichés) : total de messages envoyés depuis le
  // début (limite des gratuits) + compteur du jour (plafond des abonnés),
  // rattaché à une date-jour heure de Paris ("2026-07-05").
  static const prefLouaneCompteurTotal = 'louane_compteur_total';
  static const prefLouaneCompteurJour = 'louane_compteur_jour';
  static const prefLouaneJour = 'louane_jour';
  // L'écran « je ne suis pas un soignant » (3114/15) ne se montre qu'une fois.
  static const prefLouaneDisclaimerVu = 'louane_disclaimer_vu';

  static const prefLouanePremiereRencontre = 'louane_premiere_rencontre';
  // Variante du message d'accueil de Louane (tirée au sort, animée une seule
  // fois à la première ouverture, réaffichée telle quelle ensuite).
  static const prefLouaneIntroVariante = 'louane_intro_variante';
  static const prefNotificationsEnabled = 'notifications_enabled';
  static const prefReminderHour = 'reminder_hour';
  static const prefReminderMinute = 'reminder_minute';
  // Proposition de connexion à Apple Santé déjà faite (onboarding ou player).
  static const prefHealthPromptSeen = 'health_prompt_seen';
  // Niveau de la musique d'ambiance (curseur 0..1, 0 = coupée).
  static const prefAmbientLevel = 'ambient_level';
  // Historique d'écoute des séances (JSON {id: {fois, ts}}) : nourrit les
  // suggestions de Louane (varier, reproposer ce qui a plu). Local uniquement.
  static const prefEcoutesSeances = 'ecoutes_seances';
  // Le programme de 7 jours créé par Louane (JSON ParcoursModel). Une seule
  // clé : un programme à la fois, effacée à l'abandon ou pour recommencer.
  static const prefParcours = 'parcours_louane';
  // Vrai dès qu'un premier programme a été créé. Le backend force le jour 1
  // à « Ma première méditation » (decouverte_1) tant que ce flag est faux OU
  // qu'aucune séance n'a jamais été terminée (voir ParcoursRepository).
  static const prefParcoursDejaCree = 'parcours_deja_cree';
  static const prefParcoursEtoilesCelebrees = 'parcours_etoiles_celebrees';
  // Demande d'avis store (popup natif 5 étoiles) : date de la dernière
  // sollicitation + nombre total de sollicitations, pour ne jamais harceler.
  static const prefAvisDerniereDemande = 'avis_derniere_demande';
  static const prefAvisNbDemandes = 'avis_nb_demandes';
  // Vrai dès que la personne a laissé un retour dans la boîte aux lettres
  // (« Pas vraiment » + raisons ou mot écrit) : on ne la resollicite jamais.
  static const prefAvisRetourDonne = 'avis_retour_donne';

  // ── Audio ────────────────────────────────────────────
  // Les MP3 sont hébergés sur Firebase Storage (bucket quieto-06) à plat
  // sans sous-dossiers, pour réduire la taille du binaire iOS.
  static const audioBaseUrl =
      'https://firebasestorage.googleapis.com/v0/b/quieto-06.firebasestorage.app/o/';

  // ── Spacing ──────────────────────────────────────────
  static const spacingXs = 4.0;
  static const spacingSm = 8.0;
  static const spacingMd = 16.0;
  static const spacingLg = 24.0;
  static const spacingXl = 32.0;
  static const spacingXxl = 48.0;

  // ── Border radius ────────────────────────────────────
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 20.0;
  static const radiusXl = 28.0;

  // ── Animation durations (ms) ─────────────────────────
  static const animFast = 200;
  static const animNormal = 350;
  static const animSlow = 600;

  // ── Player ───────────────────────────────────────────
  static const playerSeekSeconds = 15;
}
