import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Clés des réponses (stockées dans SharedPreferences via saveOnboardingAnswers):
/// - 'goals'     : objectifs cochés, séparés par '|'
/// - 'q1'        : objectif prioritaire (alimente le programme)
/// - 'q_focus'   : précision sur la priorité (question adaptative)
/// - 'q2'        : expérience de méditation
/// - 'q4'        : moment de la journée — GARDE les mots matin/journée/soir,
///                 utilisés par defaultReminderTime (notification_service.dart)
/// - 'q_minutes' : durée quotidienne choisie
class OnboardingState {
  final Map<String, String> answers;
  final String firstName;

  const OnboardingState({
    this.answers = const {},
    this.firstName = '',
  });

  List<String> get goals =>
      (answers['goals'] ?? '').split('|').where((g) => g.isNotEmpty).toList();

  OnboardingState copyWith({
    Map<String, String>? answers,
    String? firstName,
  }) {
    return OnboardingState(
      answers: answers ?? this.answers,
      firstName: firstName ?? this.firstName,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setAnswer(String key, String value) {
    state = state.copyWith(answers: {...state.answers, key: value});
  }

  /// Coche/décoche un objectif. La priorité et le focus qui en dépendaient
  /// sont réinitialisés (la liste des choix de l'écran suivant change).
  void toggleGoal(String goal) {
    final goals = state.goals;
    goals.contains(goal) ? goals.remove(goal) : goals.add(goal);
    final answers = {...state.answers, 'goals': goals.join('|')};
    answers.remove('q1');
    answers.remove('q_focus');
    state = state.copyWith(answers: answers);
  }

  /// Fixe l'objectif n°1. Le focus dépend de la priorité → réinitialisé.
  void setPriority(String value) {
    final answers = {...state.answers, 'q1': value};
    answers.remove('q_focus');
    state = state.copyWith(answers: answers);
  }

  void setFirstName(String name) {
    state = state.copyWith(firstName: name);
  }
}

final onboardingProvider = StateNotifierProvider.autoDispose<
    OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
