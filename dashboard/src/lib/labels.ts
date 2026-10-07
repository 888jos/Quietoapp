// Names shown for the ids the iOS app sends. Mirrors `OnboardingStep`
// (app/ios/QuietoNative/Sources/QuietoNative/Features/Onboarding/OnboardingModels.swift).

export const ONBOARDING_STEPS: { id: string; label: string; act: number }[] = [
  { id: "splash", label: "Écran d’accueil", act: 1 },
  { id: "promise", label: "Promesse", act: 1 },
  { id: "offer", label: "Offre", act: 1 },
  { id: "firstName", label: "Prénom", act: 1 },
  { id: "reasons", label: "Ce qui t’amène", act: 2 },
  { id: "sinceWhen", label: "Depuis quand", act: 2 },
  { id: "hardestTime", label: "Moment le plus dur", act: 2 },
  { id: "sleep", label: "Sommeil", act: 2 },
  { id: "stressBefore", label: "Stress (avant)", act: 2 },
  { id: "stressSources", label: "Sources de stress", act: 2 },
  { id: "notAlone", label: "Tu n’es pas seul·e", act: 2 },
  { id: "experience", label: "Expérience méditation", act: 2 },
  { id: "blockers", label: "Freins", act: 2 },
  { id: "formats", label: "Formats", act: 2 },
  { id: "minutes", label: "Minutes par jour", act: 2 },
  { id: "moment", label: "Meilleur moment", act: 2 },
  { id: "goal", label: "Objectif 30 jours", act: 2 },
  { id: "safety", label: "Question de sécurité", act: 3 },
  { id: "crisisSupport", label: "Soutien de crise", act: 3 },
  { id: "breathIntro", label: "Intro respiration", act: 4 },
  { id: "breathing", label: "Respiration", act: 4 },
  { id: "stressAfter", label: "Stress (après)", act: 4 },
  { id: "breathResult", label: "Résultat respiration", act: 4 },
  { id: "louaneIntro", label: "Intro Louane", act: 4 },
  { id: "louaneAsk", label: "Question à Louane", act: 4 },
  { id: "louaneReply", label: "Réponse de Louane", act: 4 },
  { id: "health", label: "Apple Santé", act: 5 },
  { id: "reminders", label: "Rappels", act: 5 },
  { id: "commitment", label: "Engagement", act: 5 },
  { id: "account", label: "Compte Apple", act: 5 },
  { id: "privacy", label: "Confidentialité", act: 5 },
  { id: "building", label: "Construction du plan", act: 6 },
  { id: "profileSummary", label: "Résumé du profil", act: 6 },
  { id: "plan", label: "Plan 7 jours", act: 6 },
  { id: "projection", label: "Projection", act: 6 },
  { id: "included", label: "Ce qui est inclus", act: 6 },
  { id: "trialTimeline", label: "Déroulé de l’essai", act: 7 },
  { id: "paywall", label: "Paywall", act: 7 },
  { id: "relaunch", label: "Relance paywall", act: 7 },
  { id: "welcome", label: "Bienvenue", act: 7 },
];

/** Screens only some people see (`OnboardingViewModel.visibleSteps`). */
export const CONDITIONAL_STEPS = new Set(["crisisSupport", "health", "relaunch"]);

export const ACTS: Record<number, string> = {
  1: "Accroche",
  2: "Comprendre",
  3: "Sécurité",
  4: "Vivre l’app",
  5: "Permissions",
  6: "Plan",
  7: "Essai",
};

const stepLabels = new Map(ONBOARDING_STEPS.map((s) => [s.id, s.label]));
export const stepLabel = (id: string) => stepLabels.get(id) ?? id;

export const KIND_LABELS: Record<string, string> = {
  meditation: "Méditations guidées",
  breathing: "Respirations",
  sound: "Sons d’ambiance",
  check_in: "Check-ins",
};
