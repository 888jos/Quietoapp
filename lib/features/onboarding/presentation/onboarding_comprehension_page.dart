import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/starry_background.dart';
import '../../louane/data/louane_message.dart';
import '../../louane/presentation/widgets/louane_avatar.dart';
import '../../louane/presentation/widgets/message_bubble.dart';
import '../../paywall/paywall_providers.dart';
import '../data/accueil_louane.dart';
import 'widgets/cercle_comprehension.dart';
import 'widgets/slide_reveal.dart';

/// Fin du questionnaire, en UN SEUL écran et une seule animation continue :
///
///  1. **le compte** — le cercle analyse, le pourcentage monte, les phrases
///     tombent une à une (avec leurs vibrations) ;
///  2. **la mue** — à 100 %, le chiffre s'efface et le visage de Louane
///     apparaît À SA PLACE EXACTE, au centre du cercle. Les ondes et l'anneau
///     s'éteignent, les phrases se retirent, et tout le bloc monte vers le
///     haut de l'écran pour libérer la place ;
///  3. **la parole** — Louane écrit ce qu'elle a compris (le fond, les
///     habitudes), puis invite à l'exercice. Le bouton suit.
///
/// Un seul contrôleur par étape, aucune coupure de page : rien ne saute,
/// rien ne clignote, le regard ne perd jamais le cercle des yeux.
///
/// L'appel serveur part dès la première image, pendant que le compteur monte :
/// à la fin de la mue, les bulles sont déjà là (repli local sinon).
class OnboardingComprehensionPage extends ConsumerStatefulWidget {
  const OnboardingComprehensionPage({super.key});

  @override
  ConsumerState<OnboardingComprehensionPage> createState() =>
      _OnboardingComprehensionPageState();
}

class _PhraseData {
  final String label;
  final double threshold; // seuil de progression (0.0–1.0) déclenchant le fade
  const _PhraseData({required this.label, required this.threshold});
}

class _OnboardingComprehensionPageState
    extends ConsumerState<OnboardingComprehensionPage>
    with TickerProviderStateMixin {
  late final AnimationController _compte; // 0 → 100 %
  late final AnimationController _ondes; // boucle des vagues
  late final AnimationController _mue; // le compteur devient Louane
  late final Animation<double> _progression;

  late final List<_PhraseData> _phrases;
  final Set<int> _phrasesVibrees = {};

  /// Palier de 2 % déjà « cliqué » (le cliquetis du compteur).
  int _dernierPalier = 0;
  final _depuisTick = Stopwatch()..start();
  static const _minEntreTicks = 55; // ms — en dessous, le Taptic sature

  final _scroll = ScrollController();
  final List<String> _posees = [];
  List<String> _bulles = const [];
  bool _ecrit = false;
  bool _fini = false;
  bool _annule = false;

  /// Chargement de l'accueil, lancé dès la première image.
  Future<AccueilResultat>? _chargement;

  /// Hauteur du bloc visuel (cercle + nom) — sert à calculer sa montée.
  static const _hauteurBloc = 220.0 + 34.0;

  @override
  void initState() {
    super.initState();
    ref.read(vigieProvider).log('onboarding_etape', {'etape': 'comprehension'});
    // Précharge l'Offering RevenueCat : le paywall (3 écrans plus loin)
    // s'ouvrira avec ses prix déjà en mémoire.
    ref.read(offeringProvider.future);

    // L'appel réseau part MAINTENANT : les 5 s du compteur sont autant de
    // temps de chargement gratuit.
    _chargement = AccueilLouaneRepository(
      ref.read(storageServiceProvider),
      ref.read(vigieProvider),
    ).charger();

    _phrases = _construirePhrases();

    _ondes = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _mue = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    );

    _compte = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );
    _progression = CurvedAnimation(parent: _compte, curve: Curves.easeInOut);
    _progression.addListener(_pendantLeCompte);
    _compte.addStatusListener((status) {
      if (status == AnimationStatus.completed) _naissance();
    });
    _compte.forward();
  }

  @override
  void dispose() {
    _annule = true;
    _progression.removeListener(_pendantLeCompte);
    _compte.dispose();
    _ondes.dispose();
    _mue.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Les phrases du compte : les VRAIES réponses, c'est ce qui donne le
  /// sentiment d'avoir été lu avant même que Louane ouvre la bouche.
  List<_PhraseData> _construirePhrases() {
    final a = ref.read(storageServiceProvider).getOnboardingAnswers();
    // Tous les objectifs cochés sont cités (en version courte), pas
    // seulement le premier : la personne voit qu'on a tout retenu.
    const shortGoals = <String, String>{
      'Apaiser mon stress': 'stress',
      'Mieux dormir': 'sommeil',
      'Calmer mon anxiété': 'anxiété',
      'Me reconcentrer': 'concentration',
      'Prendre soin de moi': 'soin de toi',
    };
    final goals =
        (a['goals'] ?? '').split('|').where((g) => g.isNotEmpty).toList();
    final goalLabel = goals.length > 1
        ? 'Objectifs : ${goals.map((g) => shortGoals[g] ?? g).join(' · ')}'
        : 'Objectif : ${a['q1'] ?? 'retrouver le calme'}';
    return [
      const _PhraseData(label: 'Analyse de tes réponses', threshold: 0.00),
      _PhraseData(label: goalLabel, threshold: 0.20),
      const _PhraseData(
          label: 'Sélection des séances adaptées', threshold: 0.40),
      _PhraseData(
          label:
              'Rythme : ${a['q_minutes'] ?? 'quelques minutes'} · ${(a['q4'] ?? 'le soir').split(',').first.toLowerCase()}',
          threshold: 0.60),
      const _PhraseData(label: 'Louane lit tout ça', threshold: 0.80),
    ];
  }

  /// Pendant la montée : le cliquetis du compteur et l'arrivée des phrases.
  void _pendantLeCompte() {
    // Un tick tous les 2 %, façon molette : la courbe easeInOut fait qu'il
    // s'emballe au milieu puis se pose à l'arrivée. Le garde-fou de temps
    // évite de noyer le Taptic Engine au plus vite de la montée (il
    // ignorerait les impulsions, et le rythme paraîtrait haché).
    final palier = (_progression.value * 50).floor();
    if (palier > _dernierPalier &&
        _depuisTick.elapsedMilliseconds >= _minEntreTicks) {
      _dernierPalier = palier;
      _depuisTick.reset();
      HapticFeedback.selectionClick();
    }
    // Une phrase se pose : impact plus franc que le cliquetis.
    for (var i = 0; i < _phrases.length; i++) {
      if (_progression.value >= _phrases[i].threshold &&
          !_phrasesVibrees.contains(i)) {
        _phrasesVibrees.add(i);
        HapticFeedback.lightImpact();
      }
    }
  }

  /// 100 % : le compteur devient Louane, puis elle parle.
  Future<void> _naissance() async {
    if (_annule || !mounted) return;
    // L'impulsion qui « pose » le compteur — et fait naître le visage.
    HapticFeedback.mediumImpact();
    await _mue.forward();
    if (_annule || !mounted) return;
    // Les ondes sont éteintes depuis la mue : on arrête aussi leur boucle,
    // sinon l'écran se reconstruirait à 60 images/s pendant toute la lecture
    // des bulles pour animer quelque chose d'invisible.
    _ondes.stop();
    await _parler();
  }

  /// Pause de frappe proportionnelle à la longueur — le rythme exact du chat
  /// (`louane_providers.dart`), pour que ce premier contact et la
  /// conversation d'après ne fassent qu'un.
  Duration _pauseAvant(String bulle) =>
      Duration(milliseconds: (bulle.length * 25).clamp(700, 1800));

  Future<void> _parler() async {
    setState(() => _ecrit = true);
    final chrono = Stopwatch()..start();

    // Le repli est déjà géré dans le repository : ceci ne rend jamais null.
    final resultat = await (_chargement ??
        AccueilLouaneRepository(
          ref.read(storageServiceProvider),
          ref.read(vigieProvider),
        ).charger());
    if (_annule || !mounted) return;
    ref.read(vigieProvider).log('onboarding_accueil', {
      // Attente RESTANTE une fois le compteur fini : ~0 en temps normal,
      // les 5 s de compte ayant couvert l'appel.
      'ms': chrono.elapsedMilliseconds,
      'repli': resultat.repli,
      'bulles': resultat.bulles.length,
    });
    _bulles = resultat.bulles;

    // Frappe minimale : même si tout était prêt, Louane « finit d'écrire »
    // avant de poser sa première bulle. Sans ça, l'arrivée paraît pré-écrite.
    final reste = const Duration(milliseconds: 900) - chrono.elapsed;
    if (reste > Duration.zero) await Future.delayed(reste);

    for (var i = 0; i < _bulles.length; i++) {
      if (_annule || !mounted) return;
      if (i > 0) {
        setState(() => _ecrit = true);
        await Future.delayed(_pauseAvant(_bulles[i]));
        if (_annule || !mounted) return;
      }
      setState(() {
        _posees.add(_bulles[i]);
        _ecrit = i < _bulles.length - 1;
      });
      HapticFeedback.lightImpact();
      _versLeBas();
    }
    if (_annule || !mounted) return;
    setState(() => _fini = true);
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _continuer() {
    HapticFeedback.lightImpact();
    // Le bouton promet « 30 s » : il ouvre la respiration, rien d'autre.
    // Apple Santé vient APRÈS l'exercice (cf. onboarding_breath_page).
    context.go(AppRoutes.onboardingBreath);
  }

  /// Progression d'une sous-étape de la mue, entre [debut] et [fin].
  double _etape(double debut, double fin) =>
      ((_mue.value - debut) / (fin - debut)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            // Un seul reconstructeur pour les trois temps de l'écran : le
            // compte, la mue, les ondes. Les deux premiers se figent à la
            // fin, le troisième est arrêté juste après — passé la mue, plus
            // rien ne se reconstruit tant qu'une bulle n'arrive pas.
            child: AnimatedBuilder(
              animation: Listenable.merge([_progression, _mue, _ondes]),
              builder: (context, _) => LayoutBuilder(
              builder: (context, contraintes) {
                // Le bloc part du centre de l'écran et monte se poser en
                // haut : c'est ce déplacement qui « lève » Louane.
                final hautCentre =
                    ((contraintes.maxHeight - _hauteurBloc) / 2)
                        .clamp(0.0, contraintes.maxHeight);
                final monte = Curves.easeInOutCubic.transform(
                  _etape(0.25, 1.0),
                );
                final haut = lerpDouble(hautCentre, 8, monte)!;
                return Stack(
                  children: [
                    // ── Les bulles, sous le bloc une fois qu'il est monté ──
                    Positioned(
                      top: 8 + _hauteurBloc + AppConstants.spacingMd,
                      left: AppConstants.spacingLg,
                      right: AppConstants.spacingLg,
                      bottom: 0,
                      child: Opacity(
                        // Elles n'existent qu'une fois la place faite.
                        opacity: _etape(0.75, 1.0),
                        child: _fil(),
                      ),
                    ),
                    // ── Le cercle, puis Louane ────────────────────────────
                    Positioned(
                      top: haut,
                      left: 0,
                      right: 0,
                      child: _bloc(),
                    ),
                    // ── Les phrases du compte, sous le cercle ─────────────
                    Positioned(
                      top: haut + _hauteurBloc + AppConstants.spacingXl,
                      left: AppConstants.spacingXl,
                      right: AppConstants.spacingXl,
                      child: IgnorePointer(
                        // Elles s'effacent dès que la mue commence : Louane
                        // va redire tout ça avec ses mots.
                        child: Opacity(
                          opacity: 1 - _etape(0.0, 0.35),
                          child: _listePhrases(),
                        ),
                      ),
                    ),
                  ],
                );
              },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Le cercle et ce qu'il contient : le pourcentage, puis le visage.
  Widget _bloc() {
    final effacementChiffre = _etape(0.0, 0.20);
    final naissanceVisage = Curves.easeOutBack.transform(_etape(0.05, 0.55));
    final extinction = 1 - _etape(0.15, 0.55);

    return Column(
      children: [
        CercleComprehension(
          phaseOndes: _ondes.value,
          progression: _progression.value,
          opaciteOndes: extinction,
          opaciteAnneau: extinction,
          centre: Stack(
            alignment: Alignment.center,
            children: [
              // Le pourcentage s'efface…
              if (effacementChiffre < 1)
                Opacity(
                  opacity: 1 - effacementChiffre,
                  child: Text(
                    '${(_progression.value * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              // …et le visage prend sa place exacte, au même centre.
              if (naissanceVisage > 0)
                Opacity(
                  opacity: _etape(0.05, 0.45),
                  child: Transform.scale(
                    scale: 0.55 + 0.45 * naissanceVisage,
                    child: const LouaneAvatar(size: 96, parle: true),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingSm),
        Opacity(
          opacity: _etape(0.7, 1.0),
          child: Text(
            'Louane',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Le fil de bulles + le bouton, une fois Louane levée.
  Widget _fil() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _posees.length; i++)
                  MessageBubble(
                    // La clé fige l'animation « pop » : une bulle déjà posée
                    // ne rejoue pas quand la suivante arrive.
                    key: ValueKey('comprehension_$i'),
                    nouveau: true,
                    message: LouaneMessage(
                      auteur: AuteurMessage.louane,
                      texte: _posees[i],
                    ),
                  ),
                if (_ecrit)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: TypingBubble(),
                  ),
              ],
            ),
          ),
        ),
        // Hauteur réservée en permanence : le bouton apparaît en fondu sans
        // jamais faire sauter la mise en page.
        SizedBox(
          height: 56,
          child: AnimatedOpacity(
            opacity: _fini ? 1 : 0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !_fini,
              child: SlideReveal(
                active: _fini,
                child: AppButton(
                  label: 'Essayer maintenant (30 s)',
                  onTap: _continuer,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spacingLg),
      ],
    );
  }

  /// Les phrases cochées du compte (fondu une par une).
  Widget _listePhrases() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_phrases.length, (i) {
        // Fondu de 400 ms dès que le seuil est atteint (400/5000).
        final opacite =
            ((_progression.value - _phrases[i].threshold) / 0.08).clamp(0.0, 1.0);
        return Padding(
          padding:
              EdgeInsets.only(bottom: i < _phrases.length - 1 ? 14.0 : 0.0),
          child: Opacity(
            opacity: opacite,
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accentDim,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _phrases[i].label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
