abstract final class AppConstants {
  // ── App ──────────────────────────────────────────────
  static const appName = 'Quieto';
  // Version : source de vérité = pubspec.yaml (via package_info_plus si
  // un affichage est nécessaire un jour).

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
  static const prefNotificationsEnabled = 'notifications_enabled';
  static const prefReminderHour = 'reminder_hour';
  static const prefReminderMinute = 'reminder_minute';
  // La proposition de rappel post-première-séance ne se fait qu'une fois.
  static const prefNotificationPromptShown = 'notification_prompt_shown';

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
