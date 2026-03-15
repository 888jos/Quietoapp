import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingState {
  final Map<String, String> answers;
  final String firstName;

  const OnboardingState({
    this.answers = const {},
    this.firstName = '',
  });

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

  void setFirstName(String name) {
    state = state.copyWith(firstName: name);
  }
}

final onboardingProvider = StateNotifierProvider.autoDispose<
    OnboardingNotifier, OnboardingState>(
  (ref) => OnboardingNotifier(),
);
