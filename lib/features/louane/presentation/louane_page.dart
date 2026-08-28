import 'dart:async';
import 'dart:math' show sin, pi;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../app/router.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../parcours/parcours_providers.dart';
import '../data/louane_message.dart';
import '../louane_providers.dart';
import 'louane_palette.dart';
import 'widgets/carte_seance_louane.dart';
import 'widgets/louane_avatar.dart';
import 'widgets/louane_disclaimer_sheet.dart';
import 'widgets/louane_sommeil_sheet.dart';
import 'widgets/message_bubble.dart';

/// État de la dictée vocale.
enum _EtatVocal { inactif, ecoute, pause }

/// Page Louane : une conversation à l'écrit, façon WhatsApp.
/// En haut un bandeau « profil ». Au milieu le fil de bulles. En bas, la barre
/// de saisie : champ texte + bouton micro (champ vide → appui = on dicte) qui
/// passe à « envoyer » dès qu'on écrit. Pendant la dictée : annuler · pause ·
/// terminer (façon WhatsApp), avec une vague qui réagit quand on parle. Le
/// vocal est transcrit, déposé dans le champ pour relecture, puis envoyé.
class LouanePage extends ConsumerStatefulWidget {
  const LouanePage({super.key});

  @override
  ConsumerState<LouanePage> createState() => _LouanePageState();
}

class _LouanePageState extends ConsumerState<LouanePage>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  // Hauteur du clavier au dernier passage : sert à détecter son OUVERTURE
  // (le fil doit alors redescendre pour ne pas cacher les derniers messages).
  double _dernierClavier = 0;

  // Reconnaissance vocale (dictée).
  final SpeechToText _speech = SpeechToText();
  bool _speechDispo = false;
  _EtatVocal _vocal = _EtatVocal.inactif;
  bool _annuler = false; // session arrêtée pour annulation → ne pas remplir
  String _texteAccumule = ''; // texte figé des segments précédents
  String _texteReconnu = ''; // texte du segment d'écoute en cours
  Timer? _chrono;
  int _secondes = 0;

  // Dernier instant où des mots sont arrivés (= on parle). Sert à animer la
  // vague : récent = on parle → barres hautes ; ancien = silence → barres basses.
  final ValueNotifier<DateTime?> _dernierMot = ValueNotifier(null);

  // Nombre de messages déjà affichés : seuls les messages neufs « POP ».
  int _nbVus = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Écrire → la barre de navigation se cache (elle ne reviendra qu'en
    // défilant vers le haut dans le fil, cf. louaneNavVisibleProvider).
    _focus.addListener(() {
      if (_focus.hasFocus) {
        ref.read(louaneNavVisibleProvider.notifier).state = false;
      }
    });
    // Vigie : ouverture du chat (l'onglet Louane se construit à la 1ʳᵉ visite).
    ref.read(vigieProvider).log('louane_ouverte');
    // Chauffe en arrière-plan le résumé des évaluations Apple Santé : les
    // messages suivants partiront avec (lecture synchrone du cache). Peut
    // afficher la feuille HealthKit UNE fois pour les comptes d'avant.
    unawaited(HealthService.instance.resumeSanteMentale());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _versLeBas();
      // Première visite : « je ne suis pas un soignant » (3114/15), une fois.
      // Puis Louane tape son message d'accueil en direct (une fois aussi —
      // jouerIntro ne fait rien si l'intro a déjà été vue).
      final storage = ref.read(storageServiceProvider);
      if (!storage.louaneDisclaimerVu && mounted) {
        montrerLouaneDisclaimer(context).then((_) {
          storage.setLouaneDisclaimerVu();
          ref.read(louaneChatProvider.notifier).jouerIntro();
        });
      } else {
        ref.read(louaneChatProvider.notifier).jouerIntro();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chrono?.cancel();
    _speech.stop();
    _dernierMot.dispose();
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _envoyer() {
    final texte = _controller.text;
    if (texte.trim().isEmpty) return;
    _controller.clear();
    ref.read(louaneChatProvider.notifier).envoyer(texte);
    _versLeBas();
  }

  // ── Vocal (dictée avec pause) ───────────────────────────
  void _demarrerChrono() {
    _chrono?.cancel();
    _chrono = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondes++);
    });
  }

  Future<void> _ecouter() async {
    _texteReconnu = '';
    await _speech.listen(
      onResult: (r) {
        _texteReconnu = r.recognizedWords;
        _dernierMot.value = DateTime.now(); // des mots arrivent → on parle
      },
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        listenFor: const Duration(seconds: 120),
        pauseFor: const Duration(seconds: 30),
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        autoPunctuation:
            true, // ponctuation auto (virgules, points, ?) comme le clavier
      ),
    );
  }

  Future<void> _demarrerVocal() async {
    if (!_speechDispo) {
      _speechDispo = await _speech.initialize(
        onStatus: _onStatutVocal,
        onError: (_) {
          if (mounted) setState(() => _vocal = _EtatVocal.inactif);
        },
      );
    }
    if (!_speechDispo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Micro indisponible sur cet appareil.')),
        );
      }
      return;
    }
    HapticFeedback.lightImpact();
    _texteAccumule = '';
    _texteReconnu = '';
    _annuler = false;
    _secondes = 0;
    if (mounted) setState(() => _vocal = _EtatVocal.ecoute);
    _demarrerChrono();
    await _ecouter();
  }

  Future<void> _pauseVocal() async {
    HapticFeedback.lightImpact();
    _chrono?.cancel(); // fige le minuteur
    setState(() => _vocal = _EtatVocal.pause);
    await _speech
        .stop(); // le statut "done" verra l'état pause → reste en pause
  }

  Future<void> _reprendreVocal() async {
    HapticFeedback.lightImpact();
    setState(() => _vocal = _EtatVocal.ecoute);
    _demarrerChrono();
    await _ecouter();
  }

  void _finaliser() {
    _chrono?.cancel();
    final t = _texteAccumule.trim();
    _texteAccumule = '';
    _texteReconnu = '';
    setState(() {
      _vocal = _EtatVocal.inactif;
      _secondes = 0;
    });
    if (t.isNotEmpty) {
      _controller.text = t;
      _controller.selection = TextSelection.collapsed(offset: t.length);
    }
  }

  Future<void> _terminerVocal() async {
    HapticFeedback.lightImpact();
    if (_vocal == _EtatVocal.pause) {
      _finaliser(); // pas en écoute : on finalise directement
    } else {
      await _speech.stop(); // le statut "done" finalisera
    }
  }

  Future<void> _annulerVocal() async {
    HapticFeedback.lightImpact();
    // On coupe et on revient au champ texte TOUT DE SUITE, sans attendre le
    // retour de la reconnaissance (sur iPhone, cancel() ne rappelle pas
    // toujours le statut → sinon le bouton semblait ne rien faire).
    _annuler = true;
    _chrono?.cancel();
    _texteAccumule = '';
    _texteReconnu = '';
    if (mounted) {
      setState(() {
        _vocal = _EtatVocal.inactif;
        _secondes = 0;
      });
    }
    await _speech.cancel();
  }

  void _onStatutVocal(String status) {
    if (!mounted) return;
    if (status != 'done' && status != 'notListening') return;

    // Annulation : on jette tout.
    if (_annuler) {
      _annuler = false;
      _chrono?.cancel();
      _texteAccumule = '';
      _texteReconnu = '';
      setState(() {
        _vocal = _EtatVocal.inactif;
        _secondes = 0;
      });
      return;
    }

    // On fige le texte de ce segment.
    _texteAccumule = '$_texteAccumule $_texteReconnu'.trim();
    _texteReconnu = '';

    // En pause : on attend reprise / terminer.
    if (_vocal == _EtatVocal.pause) return;

    // Sinon (terminer manuel, ou arrêt auto après silence) : dépose + sort.
    _finaliser();
  }

  // Le clavier s'ouvre (la zone visible rétrécit) → on recolle le fil en bas,
  // sinon les derniers messages restent cachés derrière le clavier. On ne fait
  // rien à la fermeture : la place rendue ne cache rien.
  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final clavier = View.of(context).viewInsets.bottom;
    if (clavier > _dernierClavier) _versLeBas();
    _dernierClavier = clavier;
  }

  void _versLeBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(louaneChatProvider);

    // Mémorise quels messages ont déjà été affichés, pour n'animer (POP) que
    // les nouveaux et ne jamais rejouer l'animation lors des reconstructions.
    if (_nbVus != chat.messages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nbVus = chat.messages.length;
      });
    }

    // Chaque nouveau message → on redescend en bas du fil. Et si le serveur
    // signale le plafond du jour → la feuille « Louane se repose » glisse.
    ref.listen(louaneChatProvider, (avant, apres) {
      _versLeBas();
      if ((avant?.plafondEvenement ?? 0) < apres.plafondEvenement) {
        montrerLouaneSommeil(context);
      }
    });

    // L'abonnement s'active en pleine conversation (essai pris depuis le
    // paywall) → fine ligne discrète dans le fil, et la discussion reprend
    // naturellement. Jamais sur un fil vide : une nouvelle session déjà
    // abonnée n'a rien à marquer.
    ref.listen(subscriptionProvider, (avant, apres) {
      if (avant == false &&
          apres == true &&
          ref.read(louaneChatProvider).messages.isNotEmpty) {
        ref
            .read(louaneChatProvider.notifier)
            .ajouterLigneSysteme('Essai Premium activé');
      }
    });

    final nbItems = chat.messages.length + (chat.louaneEcrit ? 1 : 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _EnTete(ecrit: chat.louaneEcrit),
            Expanded(
              // Zone morte façon Snap : un tap n'importe où dans le fil range
              // le clavier — indispensable quand il y a trop peu de messages
              // pour que le « défiler pour ranger » ait de quoi défiler.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                // Défiler vers le haut (remonter dans le fil) fait
                // réapparaître la barre de navigation. Seuls les gestes de
                // la personne comptent : les défilements programmés
                // (auto-scroll vers le bas) n'émettent pas cette notification.
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (n) {
                    if (n.direction == ScrollDirection.forward &&
                        !ref.read(louaneNavVisibleProvider)) {
                      ref.read(louaneNavVisibleProvider.notifier).state = true;
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    // Rebond même liste courte → le glisser range aussi le clavier.
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: nbItems,
                    itemBuilder: (context, i) {
                      if (i >= chat.messages.length) {
                        return const TypingBubble();
                      }
                      final m = chat.messages[i];
                      // Ligne système : fine, centrée, discrète (façon
                      // séparateur de date iMessage) — pas une bulle.
                      if (m.auteur == AuteurMessage.systeme) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: Text(
                              m.texte,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        );
                      }
                      final bulle = MessageBubble(
                        key: ValueKey(i),
                        message: m,
                        nouveau: i >= _nbVus,
                      );
                      // Bulle de fin des messages découverte → bouton essai gratuit
                      // dessous (masqué si la personne s'est abonnée depuis).
                      if (m.avecBoutonEssai &&
                          !ref.watch(subscriptionProvider)) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [bulle, const _BoutonEssaiGratuit()],
                        );
                      }
                      // Louane propose le programme 7 jours → bouton dessous
                      // (masqué dès qu'un programme existe : anti-doublon).
                      if (m.avecBoutonParcours &&
                          ref.watch(parcoursProvider) == null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [bulle, const _BoutonCreerParcours()],
                        );
                      }
                      // Louane lance une séance → la carte de lancement dessous.
                      if (m.seanceId != null) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            bulle,
                            CarteSeanceLouane(
                              seanceId: m.seanceId!,
                              nouvelle: i >= _nbVus,
                            ),
                          ],
                        );
                      }
                      return bulle;
                    },
                  ),
                ),
              ),
            ),
            _BarreSaisie(
              controller: _controller,
              focusNode: _focus,
              avecSeparateur: ref.watch(louaneNavVisibleProvider),
              onEnvoyer: _envoyer,
              enregistre: _vocal != _EtatVocal.inactif,
              enPause: _vocal == _EtatVocal.pause,
              secondes: _secondes,
              dernierMot: _dernierMot,
              onMic: _demarrerVocal,
              onPause: _pauseVocal,
              onReprendre: _reprendreVocal,
              onTerminer: _terminerVocal,
              onAnnuler: _annulerVocal,
            ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête « profil » (façon WhatsApp) ───────────────────
class _EnTete extends StatelessWidget {
  final bool ecrit;

  const _EnTete({required this.ecrit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.accentDim, width: 1),
        ),
      ),
      child: Row(
        children: [
          LouaneAvatar(size: 44, parle: ecrit),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Louane', style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: LouanePalette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ecrit ? 'écrit…' : 'en ligne',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton « essai gratuit » sous la bulle de fin de découverte ──
/// Un vrai bouton d'action : centré, généreux, avec un halo turquoise
/// STATIQUE (une lueur animée scintille sur iOS, cf. feuille sommeil).
class _BoutonEssaiGratuit extends StatelessWidget {
  const _BoutonEssaiGratuit();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF86ECE4), LouanePalette.accent],
          ),
          boxShadow: [
            BoxShadow(
              color: LouanePalette.accent.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              // Même piège que le CTA programme : sans ça le clavier du chat
              // reste affiché par-dessus le paywall.
              FocusManager.instance.primaryFocus?.unfocus();
              context.push(AppRoutes.paywallDepuis('louane'));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Text(
                'Commencer mon essai gratuit',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bouton « Crée-moi mon programme » (proposition de Louane) ──
/// Même langage que le bouton essai gratuit : centré, généreux, halo
/// turquoise statique. Ouvre l'écran de génération du programme.
class _BoutonCreerParcours extends ConsumerWidget {
  const _BoutonCreerParcours();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF86ECE4), LouanePalette.accent],
          ),
          boxShadow: [
            BoxShadow(
              color: LouanePalette.accent.withValues(alpha: 0.45),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              // Le clavier du chat resterait affiché par-dessus l'écran
              // poussé (animation de création ou paywall).
              FocusManager.instance.primaryFocus?.unfocus();
              ref.read(vigieProvider).log('parcours_cta_tape');
              // Le programme 7 jours est Premium : sans abonnement, le CTA
              // mène au paywall (le backend refuse aussi la génération).
              if (!ref.read(subscriptionProvider)) {
                context.push(AppRoutes.paywallDepuis('parcours_creation'));
                return;
              }
              context.push(AppRoutes.parcoursCreation);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: AppColors.background,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Crée-moi mon programme',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.background,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Barre de saisie ───────────────────────────────────────
class _BarreSaisie extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool avecSeparateur;
  final VoidCallback onEnvoyer;
  final bool enregistre;
  final bool enPause;
  final int secondes;
  final ValueNotifier<DateTime?> dernierMot;
  final VoidCallback onMic;
  final VoidCallback onPause;
  final VoidCallback onReprendre;
  final VoidCallback onTerminer;
  final VoidCallback onAnnuler;

  const _BarreSaisie({
    required this.controller,
    required this.focusNode,
    required this.avecSeparateur,
    required this.onEnvoyer,
    required this.enregistre,
    required this.enPause,
    required this.secondes,
    required this.dernierMot,
    required this.onMic,
    required this.onPause,
    required this.onReprendre,
    required this.onTerminer,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    // Pilule de verre assortie à la barre de navigation flottante : mêmes
    // marges, pas de liseré. Barre de nav visible → collée bord à bord
    // dessus (bottom 0), fine ligne à la jonction. Barre cachée → on la
    // remonte du bord de l'écran (retour de Paul : collée en bas c'était
    // « horrible »).
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 6, 20, avecSeparateur ? 0 : 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pilule(context),
          if (avecSeparateur)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 18),
              color: Colors.white.withValues(alpha: 0.10),
            ),
        ],
      ),
    );
  }

  Widget _pilule(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            // Plus clair que le fond de page (retour de Paul : sans ça le
            // champ ne se démarque pas, on dirait du texte posé sur rien).
            color: AppColors.cardSurface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(28),
          ),
          child: enregistre
              ? _BandeauEnregistrement(
                  enPause: enPause,
                  secondes: secondes,
                  dernierMot: dernierMot,
                  onAnnuler: onAnnuler,
                  onPause: onPause,
                  onReprendre: onReprendre,
                  onTerminer: onTerminer,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppTextStyles.bodyLarge,
                        onSubmitted: (_) => onEnvoyer(),
                        decoration: InputDecoration(
                          hintText: 'Dis ce que tu as sur le cœur…',
                          hintStyle: AppTextStyles.bodyMedium,
                          // La pilule de verre EST le champ : pas de
                          // second fond par-dessus.
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder: (context, value, _) {
                        final aTexte = value.text.trim().isNotEmpty;
                        return _BoutonAction(
                          aTexte: aTexte,
                          onTap: aTexte ? onEnvoyer : onMic,
                        );
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Le bouton à droite : micro (champ vide) ↔ envoyer (dès qu'on écrit).
class _BoutonAction extends StatelessWidget {
  final bool aTexte;
  final VoidCallback onTap;

  const _BoutonAction({required this.aTexte, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Container(
          key: ValueKey(aTexte),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: aTexte ? LouanePalette.accent : AppColors.cardSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            aTexte ? Icons.arrow_upward_rounded : Icons.mic_none_rounded,
            color: aTexte ? AppColors.background : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Pendant la dictée (2 lignes façon WhatsApp) :
/// haut = point rouge + vague (barres blanches réactives) + minuteur ;
/// bas  = 🗑️ annuler · ⏸️/🎙️ pause-reprendre · ✓ terminer.
class _BandeauEnregistrement extends StatelessWidget {
  final bool enPause;
  final int secondes;
  final ValueNotifier<DateTime?> dernierMot;
  final VoidCallback onAnnuler;
  final VoidCallback onPause;
  final VoidCallback onReprendre;
  final VoidCallback onTerminer;

  const _BandeauEnregistrement({
    required this.enPause,
    required this.secondes,
    required this.dernierMot,
    required this.onAnnuler,
    required this.onPause,
    required this.onReprendre,
    required this.onTerminer,
  });

  String get _minutage {
    final m = secondes ~/ 60;
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ligne 1 : point + vague + minuteur.
        SizedBox(
          height: 34,
          child: Row(
            children: [
              const SizedBox(width: 4),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: enPause ? AppColors.textMuted : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Ondes(actif: !enPause, dernierMot: dernierMot),
              ),
              const SizedBox(width: 12),
              Text(
                _minutage,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Ligne 2 : annuler · pause/reprendre · terminer.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PetitBouton(
              icon: Icons.delete_outline_rounded,
              taille: 46,
              couleur: AppColors.cardSurface,
              iconColor: AppColors.error,
              onTap: onAnnuler,
            ),
            _PetitBouton(
              icon: enPause ? Icons.mic_rounded : Icons.pause_rounded,
              taille: 54,
              couleur: AppColors.error,
              iconColor: Colors.white,
              onTap: enPause ? onReprendre : onPause,
            ),
            _PetitBouton(
              icon: Icons.check_rounded,
              taille: 46,
              couleur: LouanePalette.accent,
              iconColor: AppColors.background,
              onTap: onTerminer,
            ),
          ],
        ),
      ],
    );
  }
}

class _PetitBouton extends StatelessWidget {
  final IconData icon;
  final double taille;
  final Color couleur;
  final Color iconColor;
  final VoidCallback onTap;

  const _PetitBouton({
    required this.icon,
    required this.taille,
    required this.couleur,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(color: couleur, shape: BoxShape.circle),
        child: Icon(icon, color: iconColor, size: taille * 0.46),
      ),
    );
  }
}

/// Vague de barres blanches qui remplit la largeur, ondule en continu, et
/// monte quand on parle (détecté via [dernierMot]) / s'aplatit en pause.
class _Ondes extends StatefulWidget {
  final bool actif;
  final ValueNotifier<DateTime?> dernierMot;

  const _Ondes({required this.actif, required this.dernierMot});

  @override
  State<_Ondes> createState() => _OndesState();
}

class _OndesState extends State<_Ondes> with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  double _intensite = 0; // 0 (silence/pause) → 1 (on parle), lissé

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flow,
      builder: (context, _) {
        final dm = widget.dernierMot.value;
        final parleRecemment =
            widget.actif &&
            dm != null &&
            DateTime.now().difference(dm).inMilliseconds < 380;
        // Cible : haut si on parle, bas si silence, ~0 si pause/inactif.
        final cible = !widget.actif ? 0.0 : (parleRecemment ? 1.0 : 0.2);
        _intensite += (cible - _intensite) * 0.16; // lissage
        return CustomPaint(
          size: const Size(double.infinity, 30),
          painter: _OndesPainter(phase: _flow.value, intensite: _intensite),
        );
      },
    );
  }
}

class _OndesPainter extends CustomPainter {
  final double phase; // 0 → 1 (déplacement de l'onde)
  final double intensite; // 0 → 1

  _OndesPainter({required this.phase, required this.intensite});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 36;
    final gap = size.width / n;
    final paint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = gap * 0.5;
    final cy = size.height / 2;
    for (var i = 0; i < n; i++) {
      final x = gap * (i + 0.5);
      // Onde qui se déplace + petite enveloppe (centre un peu plus haut).
      final onde = (sin(phase * 2 * pi + i * 0.55) + 1) / 2; // 0 → 1
      final enveloppe =
          0.6 + 0.4 * (1 - ((i - (n - 1) / 2).abs() / ((n - 1) / 2)));
      final frac = (0.1 + 0.9 * intensite) * (0.35 + 0.65 * onde) * enveloppe;
      final h = size.height * frac.clamp(0.0, 1.0);
      canvas.drawLine(Offset(x, cy - h / 2), Offset(x, cy + h / 2), paint);
    }
  }

  @override
  bool shouldRepaint(_OndesPainter old) =>
      old.phase != phase || old.intensite != intensite;
}
