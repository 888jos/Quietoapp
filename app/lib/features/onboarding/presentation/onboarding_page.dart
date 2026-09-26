import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/app_button.dart';
import '../onboarding_providers.dart';
import 'widgets/multi_question_slide.dart';
import 'widgets/progress_bar.dart';
import 'widgets/question_slide.dart';
import '../../../core/ui/starry_background.dart';
import 'widgets/text_input_slide.dart';

/// Onboarding V2 orienté conversion :
/// accueil respirant → prénom → objectifs (multi) → expérience → moment
/// → durée → création du programme. Le 1er objectif coché nomme le programme.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _controller;
  final _firstNameFocus = FocusNode();
  int _page = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: _page);
    // Vigie : chaque étape vue est tracée → on sait exactement à quelle
    // question les gens abandonnent l'onboarding.
    ref.read(vigieProvider).log('onboarding_etape', {
      'etape': _slideIds(const OnboardingState())[_page],
      'n': _page,
    });
    // Le prénom est désormais le premier écran (l'accueil est assuré par la
    // page connexion juste avant). Le clavier n'arrive qu'une fois le fondu
    // fini ET la cascade posée : s'il surgit pendant la transition, l'arrivée
    // paraît sèche.
    Future.delayed(
      const Duration(milliseconds: 800),
      () {
        if (mounted && _page == 0) _firstNameFocus.requestFocus();
      },
    );
  }

  // Vocabulaire : Quieto = espace de bien-être / santé mentale.
  // On ne parle PAS de « méditation » dans les questions (connotation),
  // sauf l'unique question expérience plus bas.
  static const _goalsOptions = [
    'Apaiser mon stress',
    'Mieux dormir',
    'Calmer mon anxiété',
    'Me reconcentrer',
    'Prendre soin de moi',
  ];

  static const _experienceOptions = [
    'Jamais essayé, c\'est tout nouveau',
    'J\'ai testé une ou deux fois',
    'Je pratique de temps en temps',
    'Je pratique régulièrement',
  ];

  // ⚠️ matin/journée/soir = mots-clés de defaultReminderTime.
  static const _momentOptions = [
    'Le matin, au réveil',
    'En journée, pour souffler',
    'Le soir, pour tout relâcher',
    'Ça dépend des jours',
  ];

  static const _minutesOptions = [
    'Moins de 5 minutes',
    'Environ 10 minutes',
    'Plus de 15 minutes',
  ];

  /// Ordre des écrans du quiz. (L'accueil est la page connexion, juste
  /// avant : pas de doublon « Bienvenue » ici.)
  List<String> _slideIds(OnboardingState state) => [
        'name',
        'goals',
        'experience',
        'moment',
        'minutes',
      ];

  bool _isSlideProceedable(OnboardingState state, List<String> ids) {
    return switch (ids[_page]) {
      'name' => state.firstName.trim().isNotEmpty,
      'goals' => state.goals.isNotEmpty,
      'experience' => state.answers.containsKey('q2'),
      'moment' => state.answers.containsKey('q4'),
      'minutes' => state.answers.containsKey('q_minutes'),
      _ => true,
    };
  }

  Future<void> _next() async {
    final state = ref.read(onboardingProvider);
    final ids = _slideIds(state);
    // Vigie : la réponse cochée sur CET écran part tout de suite — même si
    // la personne abandonne deux questions plus loin, on sait ce qu'elle
    // cherchait (anonyme : des cases cochées, jamais le prénom).
    final reponse = switch (ids[_page]) {
      'goals' => state.goals.join('|'),
      'experience' => state.answers['q2'] ?? '',
      'moment' => state.answers['q4'] ?? '',
      'minutes' => state.answers['q_minutes'] ?? '',
      _ => '',
    };
    if (reponse.isNotEmpty) {
      ref.read(vigieProvider).log('onboarding_reponse', {
        'question': ids[_page],
        'reponse': reponse,
      });
    }
    if (_page == ids.length - 1) {
      await _finish();
      return;
    }
    // L'objectif n°1 = le premier coché (il nomme le programme).
    if (ids[_page] == 'goals' && state.goals.isNotEmpty) {
      ref.read(onboardingProvider.notifier).setPriority(state.goals.first);
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: AppConstants.animNormal),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      final state = ref.read(onboardingProvider);
      final storage = ref.read(storageServiceProvider);
      await storage.saveOnboardingAnswers(state.answers);
      await storage.setFirstName(state.firstName.trim());
      await storage.setOnboardingDone();
      // Vigie : le profil coché (anonyme, jamais le prénom) → permet de
      // croiser « qui arrive » avec « qui convertit » (ex. sommeil vs stress).
      ref.read(vigieProvider).log('onboarding_fini', {
        'objectif': state.goals.isNotEmpty ? state.goals.first : '',
        'objectifs': state.goals.join('|'),
        'experience': state.answers['q2'] ?? '',
        'moment': state.answers['q4'] ?? '',
        'minutes': state.answers['q_minutes'] ?? '',
      });
      if (!mounted) return;
      ref.read(firstNameProvider.notifier).state = state.firstName.trim();
      // Fin de questionnaire : l'écran fusionné (compteur ▸ Louane ▸ résumé)
      // ou, drapeau baissé, l'ancien couple création + « voici ton programme ».
      context.go(kAccueilLouaneOnboarding
          ? AppRoutes.onboardingComprehension
          : AppRoutes.onboardingLoading);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _firstNameFocus.dispose();
    super.dispose();
  }

  /// Fondu entre slides (remplace le glissement sec du PageView).
  Widget _fade(int index, Widget child) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, c) {
        var page = _page.toDouble();
        if (_controller.hasClients) {
          page = _controller.page ?? page;
        }
        final t = (1.0 - (page - index).abs()).clamp(0.0, 1.0);
        return Opacity(opacity: t, child: c);
      },
      child: child,
    );
  }

  Widget _buildSlide(String id, int index, OnboardingState state) {
    final name = state.firstName.trim();
    final active = _page == index;

    final slide = switch (id) {
      'name' => TextInputSlide(
          active: active,
          question: "Comment tu t'appelles ?",
          hint: 'Ton prénom',
          initialValue: state.firstName,
          focusNode: _firstNameFocus,
          onChanged: (v) =>
              ref.read(onboardingProvider.notifier).setFirstName(v),
          onSubmitted:
              state.firstName.trim().isNotEmpty ? _next : null,
        ),
      'goals' => MultiQuestionSlide(
          active: active,
          question: name.isEmpty
              ? 'Qu\'est-ce qui t\'amène ici ?'
              : 'Qu\'est-ce qui t\'amène ici $name ?',
          subtitle: 'Choisis tout ce qui te parle.',
          options: _goalsOptions,
          selected: state.goals.toSet(),
          onToggle: (g) =>
              ref.read(onboardingProvider.notifier).toggleGoal(g),
        ),
      'experience' => QuestionSlide(
          active: active,
          question: 'Où en es-tu\navec la méditation ?',
          options: _experienceOptions,
          selectedOption: state.answers['q2'],
          onSelect: (v) =>
              ref.read(onboardingProvider.notifier).setAnswer('q2', v),
        ),
      'moment' => QuestionSlide(
          active: active,
          question: 'Quand aimerais-tu prendre\nun moment pour toi ?',
          options: _momentOptions,
          selectedOption: state.answers['q4'],
          onSelect: (v) =>
              ref.read(onboardingProvider.notifier).setAnswer('q4', v),
        ),
      'minutes' => QuestionSlide(
          active: active,
          question: 'Combien de temps peux-tu\nt\'offrir chaque jour ?',
          options: _minutesOptions,
          selectedOption: state.answers['q_minutes'],
          onSelect: (v) => ref
              .read(onboardingProvider.notifier)
              .setAnswer('q_minutes', v),
        ),
      _ => const SizedBox.shrink(),
    };
    return _fade(index, slide);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final ids = _slideIds(state);
    final canProceed = _isSlideProceedable(state, ids);
    final quizSteps = ids.length;
    final isLast = _page == ids.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      // false = le clavier glisse PAR-DESSUS sans compresser la mise en page
      // (sinon tous les widgets « se recollent » brutalement à l'arrivée sur
      // l'écran prénom). Le champ est centré → toujours visible ; la touche
      // OK du clavier valide et passe à la suite.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingLg),
              child: Column(
                children: [
                  const SizedBox(height: AppConstants.spacingSm),
                  // Flèche retour : entre les questions, elle recule d'un
                  // écran ; sur la première (prénom), elle ramène à la page
                  // connexion (utile pour qui a tapé « sans compte » et
                  // change d'avis).
                  SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.textMuted,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          // Referme le clavier avant de reculer (sinon il
                          // reste ouvert sur l'écran d'arrivée).
                          _firstNameFocus.unfocus();
                          if (_page == 0) {
                            context.go(AppRoutes.onboardingConnexion);
                            return;
                          }
                          _controller.previousPage(
                            duration: const Duration(
                                milliseconds: AppConstants.animNormal),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),
                  // Barre de progression : hauteur RÉSERVÉE en permanence
                  // (sinon la mise en page saute pendant la transition 0→1),
                  // simple fondu à l'apparition.
                  const SizedBox(height: AppConstants.spacingSm),
                  SizedBox(
                    height: 3,
                    child: OnboardingProgressBar(
                      current: _page.clamp(0, quizSteps - 1),
                      total: quizSteps,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Expanded(
                    child: PageView(
                      controller: _controller,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (i) {
                        setState(() => _page = i);
                        if (i < ids.length) {
                          ref.read(vigieProvider).log('onboarding_etape',
                              {'etape': ids[i], 'n': i});
                        }
                        if (ids.length > i && ids[i] == 'name') {
                          // Clavier seulement une fois la transition finie
                          // (sinon il pousse la mise en page en plein fondu).
                          Future.delayed(
                            const Duration(
                                milliseconds: AppConstants.animNormal + 150),
                            () {
                              if (mounted && _page == i) {
                                _firstNameFocus.requestFocus();
                              }
                            },
                          );
                        } else {
                          _firstNameFocus.unfocus();
                        }
                      },
                      children: [
                        for (var i = 0; i < ids.length; i++)
                          _buildSlide(ids[i], i, state),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  AppButton(
                    label: isLast ? 'Créer mon programme' : 'Continuer',
                    onTap: canProceed ? _next : null,
                    isLoading: _loading,
                  ),
                  const SizedBox(height: AppConstants.spacingLg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
