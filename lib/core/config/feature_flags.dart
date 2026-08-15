/// Interrupteurs de fonctionnalités : une constante à basculer, rien d'autre
/// à toucher. Le code des deux chemins reste en place tant qu'un choix n'est
/// pas définitif — c'est ce qui permet de revenir en arrière en une ligne,
/// sans revert ni redéploiement du serveur.
library;

/// Fin de l'onboarding : un seul écran (`/onboarding-comprehension`) où le
/// compteur monte, où Louane naît du cercle à 100 %, se lève, puis dit ce
/// qu'elle a compris avant d'emmener faire l'exercice.
///
/// `true`  → questionnaire ▸ **compréhension** ▸ santé (iOS) ▸ respiration
/// `false` → questionnaire ▸ création (le compteur seul) ▸ « voici ton
///           programme » ▸ santé (iOS) ▸ respiration — le parcours d'avant le
///           15/08/2026, intact : `onboarding_loading_page.dart`,
///           `onboarding_ready_page.dart` et `weekly_program.dart` ne sont
///           pas supprimés.
///
/// Pourquoi le changement : le programme de 7 jours montré à l'onboarding
/// n'était jamais enregistré ni réaffiché (`buildWeeklyProgram` n'a qu'un
/// seul appelant), et il grillait la promesse du VRAI programme, celui que
/// Louane crée plus tard dans la conversation.
const kAccueilLouaneOnboarding = true;
