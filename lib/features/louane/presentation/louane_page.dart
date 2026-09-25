import 'dart:async';
import 'dart:math' show sin, pi;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, HapticFeedback, LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../../../app/router.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/verre_apple.dart';
import '../../parcours/parcours_providers.dart';
import 'widgets/carte_analyse_sante.dart';
import 'widgets/louane_sante_sheet.dart';
import '../../../core/ui/apple_health_icon.dart';
import '../data/louane_message.dart';
import '../louane_providers.dart';
import 'louane_palette.dart';
import 'widgets/carte_seance_louane.dart';
import 'widgets/louane_avatar.dart';
import 'widgets/louane_disclaimer_sheet.dart';
import 'widgets/louane_sommeil_sheet.dart';
import 'widgets/menu_bulle.dart';
import 'widgets/message_bubble.dart';

/// État de la dictée vocale.
enum _EtatVocal { inactif, ecoute, pause }

/// Page Louane : une conversation à l'écrit, façon WhatsApp.
/// En haut un bandeau « profil ». Au milieu le fil de bulles. En bas, la barre
/// de saisie : champ texte + bouton micro qui passe à « envoyer » dès qu'on
/// écrit. Champ vide : un APPUI sur le micro lance la dictée : annuler ·
/// pause · terminer (façon WhatsApp), avec une
/// vague qui réagit quand on parle, le texte déposé dans le champ pour
/// relecture, puis envoyé.
///
/// APPUI LONG sur une bulle (demande de Paul, 22/09/2026, « exactement
/// comme dans l'app Claude ») : la bulle gonfle sous le doigt, petite
/// vibration, le fil se floute, et un popup sort de la bulle (voir
/// menu_bulle.dart) — date et heure, Copier, Sélectionner le texte ; sur ses
/// propres messages aussi Modifier (le texte revient dans la barre de
/// saisie, la suite de la discussion sera remplacée), Renvoyer tel quel,
/// Supprimer (avec Annuler).
class LouanePage extends ConsumerStatefulWidget {
  const LouanePage({super.key});

  @override
  ConsumerState<LouanePage> createState() => _LouanePageState();
}

/// `sante_lecture` part une seule fois par session d'app, quel que soit le
/// nombre d'ouvertures du fil.
bool _lectureSanteTracee = false;

class _LouanePageState extends ConsumerState<LouanePage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  // Hauteur du clavier au dernier passage : sert à détecter son OUVERTURE
  // (le fil doit alors redescendre pour ne pas cacher les derniers messages).
  double _dernierClavier = 0;

  /// Hauteur RÉELLE occupée par la barre de saisie (pilule + ses marges,
  /// barre de nav comprise), mesurée après chaque mise en page. Le fil
  /// s'en sert pour laisser toujours une respiration entre son dernier
  /// message et la pilule — avant, une marge fixe de 82 laissait la pilule
  /// seule en bas (26 de décollage) mordre sur la dernière bulle, et bien
  /// plus quand on écrit sur plusieurs lignes (retour de Paul, 07/09/2026).
  /// Null tant qu'on n'a pas mesuré : on retombe sur une estimation.
  double? _hautBarre;
  final _cleBarre = GlobalKey();

  /// L'en-tête en verre dépoli flotte AU-DESSUS du fil (Paul, 12/09) : le
  /// fil défile dessous, et commence donc sous sa hauteur, mesurée.
  double? _hautEnTete;
  final _cleEnTete = GlobalKey();

  void _mesureEnTete() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = _cleEnTete.currentContext?.size?.height;
      if (h == null || h == 0) return;
      if (_hautEnTete == null || (h - _hautEnTete!).abs() > 0.5) {
        setState(() => _hautEnTete = h);
      }
    });
  }

  void _mesureBarre() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final h = _cleBarre.currentContext?.size?.height;
      if (h == null || h == 0) return;
      if (_hautBarre == null || (h - _hautBarre!).abs() > 0.5) {
        setState(() => _hautBarre = h);
      }
    });
  }

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

  // Instant d'ouverture de la session : la fine ligne de date en tête de
  // fil (« Aujourd'hui 14:20 », façon iMessage) l'affiche tel quel.
  late final DateTime _ouverture;

  // Jours entiers depuis la première rencontre avec Louane (0 = aujourd'hui).
  int _joursEnsemble = 0;

  @override
  void initState() {
    super.initState();
    _ouverture = DateTime.now();
    // « Avec toi depuis X jours » : lu AVANT de poser la date (première
    // visite → null → 0 jour, ce qui est vrai).
    final premiereRencontre = ref
        .read(storageServiceProvider)
        .louanePremiereRencontre;
    _joursEnsemble = premiereRencontre == null
        ? 0
        : DateTime.now().difference(premiereRencontre).inDays;
    unawaited(ref.read(storageServiceProvider).marqueLouanePremiereRencontre());
    WidgetsBinding.instance.addObserver(this);
    // Écrire → la barre de navigation se cache (elle ne reviendra qu'en
    // défilant vers le haut dans le fil, cf. louaneNavRevelationProvider).
    _focus.addListener(() {
      if (_focus.hasFocus) {
        ref.read(louaneNavRevelationProvider.notifier).state = 0.0;
      }
    });
    // Vigie : ouverture du chat (l'onglet Louane se construit à la 1ʳᵉ visite).
    ref.read(vigieProvider).log('louane_ouverte');
    // Chauffe en arrière-plan le résumé des évaluations Apple Santé : les
    // messages suivants partiront avec (lecture synchrone du cache). Peut
    // afficher la feuille HealthKit UNE fois pour les comptes d'avant.
    // Relecture à chaque ouverture du fil (pas seulement la première de la
    // session) : un questionnaire rempli entre-temps est vu. Vigie, UNE fois
    // par session : quelle part des iPhone ont un questionnaire lisible
    // (demande de Paul, 12/09) — `sante_lecture {questionnaire}`.
    unawaited(HealthService.instance.rafraichir().then((_) {
      if (_lectureSanteTracee || !HealthService.instance.disponible) return;
      _lectureSanteTracee = true;
      ref.read(vigieProvider).log('sante_lecture', {
        'questionnaire': HealthService.instance.testSante?.name ?? 'aucun',
        'signaux': HealthService.instance.signaux.length,
      });
    }).catchError((Object e) {
      // Une lecture qui échoue doit se voir dans la Vigie, pas se taire.
      if (_lectureSanteTracee || !mounted) return;
      _lectureSanteTracee = true;
      ref.read(vigieProvider).log('sante_lecture', {'questionnaire': 'erreur'});
    }));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _versLeBas();
      // Première visite : « je ne suis pas un soignant » (3114/15), une fois.
      // Puis Louane tape son message d'accueil en direct (une fois aussi —
      // jouerIntro ne fait rien si l'intro a déjà été vue).
      final storage = ref.read(storageServiceProvider);
      if (!storage.louaneDisclaimerVu && mounted) {
        // Pendant la feuille, la pilule de nav disparaît (demande de Paul) :
        // elle vit au-dessus du navigateur d'onglet et recouvrait le bouton
        // « J'ai compris ». Elle revient une fois la feuille refermée.
        ref.read(louaneNavRevelationProvider.notifier).state = 0.0;
        montrerLouaneDisclaimer(context).then((_) {
          storage.setLouaneDisclaimerVu();
          if (!mounted) return;
          ref.read(louaneNavRevelationProvider.notifier).state = 1.0;
          ref.read(louaneChatProvider.notifier).jouerIntro();
        });
      } else {
        ref.read(louaneChatProvider.notifier).jouerIntro();
      }
    });
  }

  /// Retour au premier plan : on relit Santé. Le cas typique : la personne
  /// va remplir le questionnaire dans l'app Santé et revient demander son
  /// programme — Louane doit le voir sans redémarrage.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(HealthService.instance.rafraichir());
    }
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
    _navAnim.dispose();
    super.dispose();
  }

  void _envoyer() {
    final texte = _controller.text;
    if (texte.trim().isEmpty) return;
    _controller.clear();
    final modification = _modification;
    if (modification != null) {
      // Le message modifié repart : la suite du fil est remplacée.
      setState(() => _modification = null);
      _brouillonAvant = '';
      _ajusterVus(modification);
      ref.read(louaneChatProvider.notifier).renvoyer(modification, texte);
    } else {
      ref.read(louaneChatProvider.notifier).envoyer(texte);
    }
    _versLeBas();
  }

  // ── Actions sur une bulle (appui long) ──────────────────
  /// Index du message de la personne en cours de modification (null sinon).
  int? _modification;

  /// Ce qui était tapé dans la barre avant de modifier : rendu si on annule.
  String _brouillonAvant = '';

  /// Les bulles à partir de [i] repartent de zéro : elles s'animeront comme
  /// des messages neufs (sinon le compteur de « déjà vus » les prend pour
  /// d'anciennes bulles jusqu'au frame suivant).
  void _ajusterVus(int i) {
    if (_nbVus > i) _nbVus = i;
  }

  Future<void> _menuBulle(
    Rect rect,
    int iMsg,
    LouaneMessage m, {
    required bool premier,
    required bool dernier,
    required bool ample,
  }) async {
    final chat = ref.read(louaneChatProvider);
    final mien = m.auteur == AuteurMessage.user;
    // Pendant que Louane écrit, on ne touche pas au fil (copier reste possible).
    final modifiable = mien && !chat.louaneEcrit;
    final choix = await montrerMenuBulle(
      context,
      rect: rect,
      message: m,
      premierDuGroupe: premier,
      dernierDuGroupe: dernier,
      ample: ample,
      actions: [
        const ActionBulle('copier', Icons.copy_rounded, 'Copier'),
        const ActionBulle(
            'selectionner', Icons.select_all_rounded, 'Sélectionner le texte'),
        if (modifiable)
          const ActionBulle('modifier', Icons.edit_rounded, 'Modifier'),
        if (modifiable)
          const ActionBulle('renvoyer', Icons.refresh_rounded, 'Renvoyer'),
        if (modifiable)
          const ActionBulle(
              'supprimer', Icons.delete_outline_rounded, 'Supprimer',
              danger: true),
      ],
    );
    if (!mounted || choix == null) return;
    final notifier = ref.read(louaneChatProvider.notifier);
    switch (choix) {
      case 'copier':
        await Clipboard.setData(ClipboardData(text: m.texte));
        ref.read(vigieProvider).log('louane_message_copie', {'mien': mien});
        _toast('Message copié');
      case 'selectionner':
        ref.read(vigieProvider).log('louane_message_selection', {'mien': mien});
        await _selectionnerTexte(m);
      case 'modifier':
        _brouillonAvant = _modification == null ? _controller.text : _brouillonAvant;
        setState(() => _modification = iMsg);
        _controller.text = m.texte;
        _controller.selection =
            TextSelection.collapsed(offset: m.texte.length);
        _focus.requestFocus();
      case 'renvoyer':
        _annulerModification();
        _ajusterVus(iMsg);
        unawaited(notifier.renvoyer(iMsg, m.texte));
        _versLeBas();
      case 'supprimer':
        _annulerModification();
        final retires = notifier.supprimer(iMsg);
        if (retires.isEmpty) return;
        _ajusterVus(iMsg);
        _toast(
          retires.length > 1
              ? 'Message et réponse supprimés'
              : 'Message supprimé',
          action: SnackBarAction(
            label: 'Annuler',
            textColor: LouanePalette.accent,
            onPressed: () => notifier.restaurer(iMsg, retires),
          ),
          duree: const Duration(seconds: 4),
        );
    }
  }

  /// « Sélectionner le texte » : le message seul, en grand, sélectionnable
  /// mot à mot (feuille sombre qui glisse du bas).
  Future<void> _selectionnerTexte(LouaneMessage m) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final haut = MediaQuery.sizeOf(ctx).height * 0.7;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sélectionner le texte',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.45),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: haut),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      m.texte,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _annulerModification() {
    if (_modification == null) return;
    setState(() => _modification = null);
    _controller.text = _brouillonAvant;
    _controller.selection =
        TextSelection.collapsed(offset: _brouillonAvant.length);
    _brouillonAvant = '';
  }

  /// Petit mot flottant au-dessus de la pilule de saisie.
  void _toast(String texte,
      {SnackBarAction? action, Duration duree = const Duration(milliseconds: 1400)}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(texte, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
      action: action,
      duration: duree,
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF1B2F4E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.fromLTRB(
          16, 0, 16, (_hautBarre ?? MediaQuery.paddingOf(context).bottom + 92) + 10),
    ));
  }

  // ── Dictée (appui sur le micro) ─────────────────────────
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
      _speechDispo = await _speech.initialize();
    }
    // Le moteur de dictée est un singleton, et
    // initialize() ne repose pas les écouteurs s'il a déjà servi : on les
    // pose à la main, à chaque dictée.
    _speech.statusListener = _onStatutVocal;
    _speech.errorListener = (_) {
      if (mounted) setState(() => _vocal = _EtatVocal.inactif);
    };
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

  // ── Barre de navigation au geste (retour de Paul, 12/09) ──
  /// Défilement vers le haut (en points) qui révèle la barre en entier.
  static const _distanceRevelationNav = 140.0;

  /// Révélée au moins jusque-là quand on lâche → elle finit de sortir ;
  /// en dessous, elle rentre.
  static const _seuilRevelationNav = 0.45;

  late final AnimationController _navAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addListener(_tickNav);
  double _navDepart = 1;
  double _navCible = 1;
  bool _doigtSurLeFil = false;

  void _tickNav() {
    final t = Curves.easeOutCubic.transform(_navAnim.value);
    ref.read(louaneNavRevelationProvider.notifier).state =
        _navDepart + (_navCible - _navDepart) * t;
  }

  /// Doigt levé : on termine le geste, dans un sens ou dans l'autre.
  void _finirGesteNav() {
    final f = ref.read(louaneNavRevelationProvider);
    if (f <= 0 || f >= 1) return;
    _navDepart = f;
    _navCible = f >= _seuilRevelationNav ? 1 : 0;
    _navAnim.forward(from: 0);
  }

  /// Seuls les gestes de la personne comptent (dragDetails) : les
  /// défilements programmés (auto-scroll vers le bas) ne bougent rien.
  /// Remonter dans le fil révèle la barre proportionnellement, descendre
  /// la rentre de même.
  bool _surDefilement(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _doigtSurLeFil = true;
      _navAnim.stop();
    } else if (n is ScrollUpdateNotification) {
      if (n.dragDetails != null) {
        _doigtSurLeFil = true;
        final delta = n.scrollDelta ?? 0;
        if (delta != 0) {
          final f = (ref.read(louaneNavRevelationProvider) -
                  delta / _distanceRevelationNav)
              .clamp(0.0, 1.0);
          ref.read(louaneNavRevelationProvider.notifier).state = f;
        }
      } else if (_doigtSurLeFil) {
        _doigtSurLeFil = false;
        _finirGesteNav();
      }
    } else if (n is ScrollEndNotification && _doigtSurLeFil) {
      _doigtSurLeFil = false;
      _finirGesteNav();
    }
    return false;
  }

  /// Le popup « Louane analyse » déjà ouvert pour cet instant de départ :
  /// jamais deux fois pour la même carte.
  DateTime? _analyseAffichee;

  /// L'avatar de l'en-tête, mesuré pour faire partir le vol de là.
  final _cleAvatar = GlobalKey();

  /// Le dernier message est une analyse Santé encore en cours et pas encore
  /// montrée → le popup sort du chat (fond flouté), et se referme seul.
  void _montrerAnalyseSiBesoin(LouaneChatState chat) {
    if (chat.messages.isEmpty) return;
    final m = chat.messages.last;
    final debut = m.analyseDebut;
    final analyse = m.analyse;
    if (analyse == null || debut == null || debut == _analyseAffichee) return;
    if (DateTime.now().difference(debut) >= analyse.duree) return;
    _analyseAffichee = debut;
    // D'où part Louane : son avatar dans l'en-tête (coordonnées écran).
    Rect? origine;
    final boite = _cleAvatar.currentContext?.findRenderObject();
    if (boite is RenderBox && boite.attached && boite.hasSize) {
      origine = boite.localToGlobal(Offset.zero) & boite.size;
      ref.read(louaneAvatarEnVolProvider.notifier).state = true;
    }
    montrerAnalyseSante(
      context,
      analyse: analyse,
      debut: debut,
      origine: origine,
    ).whenComplete(() {
      // Le popup est refermé : l'avatar finit son vol retour, puis l'en-tête
      // reprend le sien.
      Future.delayed(kDureeVolAvatar, () {
        if (mounted) {
          ref.read(louaneAvatarEnVolProvider.notifier).state = false;
        }
      });
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
      _montrerAnalyseSiBesoin(apres);
    });
    // Le moment d'analyse a pu commencer avant que cette page existe (démo
    // lancée depuis l'accueil) : on le rattrape juste après ce build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _montrerAnalyseSiBesoin(ref.read(louaneChatProvider));
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

    // La fine ligne de date coiffe le fil dès qu'il a des messages (sur un
    // fil vide elle flotterait toute seule pendant le disclaimer). Elle
    // décale les index d'un cran : [iMsg] ci-dessous fait la conversion.
    final avecLigneDate = chat.messages.isNotEmpty;
    final nbItems =
        chat.messages.length +
        (chat.louaneEcrit ? 1 : 0) +
        (avecLigneDate ? 1 : 0);

    // Marge basse du fil : la barre de saisie telle qu'elle est vraiment
    // (mesurée, marges et barre de nav comprises) + une respiration de 14,
    // pour que la pilule ne morde jamais sur la dernière bulle. Le fil défile
    // DERRIÈRE la pilule et la nav — seuls les ovales flottent, autour tout
    // passe à travers (demande de Paul du 28/08). Avant la première mesure :
    // estimation (pilule ~66 + décollage 26).
    const respiration = 14.0;
    final basFil =
        (_hautBarre ?? MediaQuery.paddingOf(context).bottom + 92) + respiration;
    _mesureBarre();
    _mesureEnTete();
    final hautStatut = MediaQuery.paddingOf(context).top;

    final enTete = _EnTete(
      ecrit: chat.louaneEcrit,
      analyse:
          chat.messages.isNotEmpty && chat.messages.last.estCarteAnalyse,
      cleAvatar: _cleAvatar,
      avatarEnVol: ref.watch(louaneAvatarEnVolProvider),
      teLit: chat.messages.isNotEmpty &&
          chat.messages.last.auteur == AuteurMessage.user,
      jours: _joursEnsemble,
      onSante: () {
        HapticFeedback.lightImpact();
        FocusManager.instance.primaryFocus?.unfocus();
        ref.read(vigieProvider).log('louane_sante_ouverte');
        montrerLouaneSante(
          context,
          onConnexion: () =>
              ref.read(vigieProvider).log('louane_sante_connexion'),
        );
      },
      onInfo: () {
        HapticFeedback.lightImpact();
        FocusManager.instance.primaryFocus?.unfocus();
        montrerLouaneDisclaimer(context);
      },
    );

    return Scaffold(
      backgroundColor: LouanePalette.fondChat,
      // Fond UNI, un cran plus sombre que le reste de l'app : les bulles
      // ressortent (Paul, 12/09 : le dégradé, « laid »).
      body: ColoredBox(
        color: LouanePalette.fondChat,
        // Pas de zone sûre en haut : le fil monte jusque sous l'heure de
        // l'iPhone et s'y efface dans le voile (façon Instagram, Paul 12/09).
        child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    // Zone morte façon Snap : un tap n'importe où dans le
                    // fil range le clavier — indispensable quand il y a trop
                    // peu de messages pour que le « défiler pour ranger »
                    // ait de quoi défiler.
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      // Remonter dans le fil fait sortir la barre de
                      // navigation AVEC le doigt ; descendre la rentre
                      // (demande de Paul du 28/08, geste progressif le
                      // 12/09). Voir _surDefilement.
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _surDefilement,
                        child: ListView.builder(
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          // Rebond même liste courte → le glisser range aussi le clavier.
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          // Le fil commence sous l'en-tête en verre ET sous
                          // le débord du voile : au repos, la ligne de date
                          // reste nette ; elle ne se floute qu'en remontant
                          // (retour de Paul, 12/09).
                          padding: EdgeInsets.fromLTRB(
                              16,
                              hautStatut +
                                  (_hautEnTete ?? 66) +
                                  _VoileEnTete.debord +
                                  6,
                              16,
                              basFil),
                          itemCount: nbItems,
                          itemBuilder: (context, i) {
                            if (avecLigneDate && i == 0) {
                              return _LigneDate(ouverture: _ouverture);
                            }
                            final iMsg = avecLigneDate ? i - 1 : i;
                            if (iMsg >= chat.messages.length) {
                              return const TypingBubble();
                            }
                            final m = chat.messages[iMsg];
                            // Ligne système : fine, centrée, discrète (façon
                            // séparateur de date iMessage) — pas une bulle.
                            if (m.auteur == AuteurMessage.systeme) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Center(
                                  child: Text(
                                    m.texte,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(
                                        alpha: 0.35,
                                      ),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              );
                            }
                            // Louane a lu le questionnaire Santé (le popup
                            // est passé) : une petite pilule avec l'icône
                            // Santé, qui porte de l'info et se lit.
                            if (m.estCarteAnalyse) {
                              return Center(
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  padding: const EdgeInsets.fromLTRB(
                                      11, 6, 13, 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.10),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const AppleHealthIcon(size: 13),
                                      const SizedBox(width: 7),
                                      Text(
                                        libelleAnalyse(m.analyse!),
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          letterSpacing: 0.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            // Groupement façon Messages : des bulles qui se
                            // suivent du même côté se serrent.
                            bool memeGroupe(int j) {
                              if (j < 0 || j >= chat.messages.length) {
                                return false;
                              }
                              final autre = chat.messages[j];
                              return autre.auteur == m.auteur &&
                                  autre.auteur != AuteurMessage.systeme &&
                                  !autre.estCarteAnalyse;
                            }

                            final premier = !memeGroupe(iMsg - 1);
                            final dernier = !memeGroupe(iMsg + 1);
                            final bulle = MessageBubble(
                              key: ValueKey(iMsg),
                              message: m,
                              nouveau: iMsg >= _nbVus,
                              premierDuGroupe: premier,
                              dernierDuGroupe: dernier,
                              depuisSaisie: !m.estLouane,
                              onLongPress: (rect) => _menuBulle(
                                rect,
                                iMsg,
                                m,
                                premier: premier,
                                dernier: dernier,
                                ample: false,
                              ),
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
                                    nouvelle: iMsg >= _nbVus,
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
                  // Le voile du haut : barre d'état + en-tête, sous lesquels
                  // les messages se floutent de plus en plus et s'effacent.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: _VoileEnTete(
                      hautStatut: hautStatut,
                      child: KeyedSubtree(key: _cleEnTete, child: enTete),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: NotificationListener<SizeChangedLayoutNotification>(
                      onNotification: (_) {
                        _mesureBarre();
                        return true;
                      },
                      child: SizeChangedLayoutNotifier(
                        child: KeyedSubtree(
                          key: _cleBarre,
                          child: _BarreSaisie(
                            controller: _controller,
                            focusNode: _focus,
                            revelationNav:
                                ref.watch(louaneNavRevelationProvider),
                            onEnvoyer: _envoyer,
                            modification: _modification != null,
                            suiteRemplacee: _modification != null &&
                                _modification! < chat.messages.length - 1,
                            onAnnulerModification: _annulerModification,
                            enregistre: _vocal != _EtatVocal.inactif,
                            enPause: _vocal == _EtatVocal.pause,
                            secondes: _secondes,
                            dernierMot: _dernierMot,
                            onDictee: _demarrerVocal,
                            onPause: _pauseVocal,
                            onReprendre: _reprendreVocal,
                            onTerminer: _terminerVocal,
                            onAnnuler: _annulerVocal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ── En-tête « profil » (façon WhatsApp) ───────────────────
/// Le sous-titre est VIVANT (retour de Paul du 30/08 : le « en ligne » figé
/// faisait vide) : « te lit… » un instant après l'envoi, puis « écrit… »
/// pendant la frappe ; au repos « en ligne · avec toi depuis X jours », et
/// le soir « pense à toi ce soir ». Rien d'autre ne bouge : ni l'avatar,
/// ni le nom, et AUCUN bouton en plus.
class _EnTete extends StatefulWidget {
  final bool ecrit;

  /// La carte d'analyse Santé est le dernier élément du fil : Louane lit le
  /// questionnaire (l'avatar s'anime, le statut le dit).
  final bool analyse;

  /// Pour mesurer l'avatar : c'est de là que part son vol vers le popup.
  final GlobalKey? cleAvatar;

  /// L'avatar est parti réfléchir au-dessus du popup d'analyse : sa place
  /// reste, lui s'efface le temps du vol.
  final bool avatarEnVol;

  /// Le dernier message du fil vient de la personne : avant d'écrire,
  /// Louane commence par le lire.
  final bool teLit;

  /// Jours entiers depuis la première rencontre (0 = aujourd'hui).
  final int jours;

  /// Les deux petits boutons ronds de droite, façon Instagram (Paul, 12/09 :
  /// « sinon ça fait vide ») : ce que Louane voit dans Apple Santé, et qui
  /// est Louane.
  final VoidCallback? onSante;
  final VoidCallback? onInfo;

  const _EnTete({
    required this.ecrit,
    this.analyse = false,
    this.cleAvatar,
    this.avatarEnVol = false,
    required this.teLit,
    required this.jours,
    this.onSante,
    this.onInfo,
  });

  @override
  State<_EnTete> createState() => _EnTeteState();
}

class _EnTeteState extends State<_EnTete> {
  static const _dureeLecture = Duration(milliseconds: 1600);
  Timer? _timerLecture;
  bool _enLecture = false;

  @override
  void didUpdateWidget(_EnTete ancien) {
    super.didUpdateWidget(ancien);
    // Louane se met à répondre au message de la personne : « te lit… »
    // d'abord, la frappe ensuite. Entre deux bulles d'une même réponse (le
    // dernier message est le sien), elle n'a rien à relire.
    if (widget.ecrit && !ancien.ecrit && widget.teLit) {
      _enLecture = true;
      _timerLecture?.cancel();
      _timerLecture = Timer(_dureeLecture, () {
        if (mounted) setState(() => _enLecture = false);
      });
    } else if (!widget.ecrit && ancien.ecrit) {
      _timerLecture?.cancel();
      _enLecture = false;
    }
  }

  @override
  void dispose() {
    _timerLecture?.cancel();
    super.dispose();
  }

  /// « avec toi depuis… » — null le tout premier jour (rien à raconter).
  String? _relation() {
    final j = widget.jours;
    if (j < 1) return null;
    if (j == 1) return 'avec toi depuis hier';
    if (j < 60) return 'avec toi depuis $j jours';
    if (j < 365) return 'avec toi depuis ${j ~/ 30} mois';
    return "avec toi depuis plus d'un an";
  }

  String _statut() {
    if (widget.ecrit) return _enLecture ? 'te lit…' : 'écrit…';
    if (widget.analyse) return 'lit ton questionnaire…';
    final h = DateTime.now().hour;
    if (h >= 21) return 'pense à toi ce soir';
    if (h < 5) return 'là, même en pleine nuit';
    final relation = _relation();
    return relation == null ? 'en ligne' : 'en ligne · $relation';
  }

  @override
  Widget build(BuildContext context) {
    final statut = _statut();
    // Contenu transparent : le flou et le fondu vivent dans _VoileEnTete,
    // qui couvre aussi la barre d'état (façon Instagram, Paul 12/09). Pas de
    // trait, pas de flèche retour (la navigation vit en bas).
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
      child: Row(
        children: [
          KeyedSubtree(
            key: widget.cleAvatar,
            child: AnimatedOpacity(
              opacity: widget.avatarEnVol ? 0 : 1,
              duration: const Duration(milliseconds: 160),
              child: LouaneAvatar(
                size: 44,
                parle: widget.ecrit || widget.analyse,
              ),
            ),
          ),
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
                    // Fondu discret entre deux statuts : le texte change,
                    // rien ne saute.
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          statut,
                          key: ValueKey(statut),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BoutonRond(
            enfant: const AppleHealthIcon(size: 19),
            libelle: 'Ce que Louane voit dans Apple Santé',
            onTap: widget.onSante,
          ),
          const SizedBox(width: 8),
          _BoutonRond(
            enfant: Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            libelle: 'Qui est Louane',
            onTap: widget.onInfo,
          ),
        ],
      ),
    );
  }
}

/// Le voile du haut de page, façon Instagram : les messages qui montent
/// sous l'en-tête deviennent de plus en plus flous, puis s'effacent dans le
/// fond juste sous l'heure de l'iPhone.
///
/// Le flou progressif est fait de nombreuses couches de flou LÉGÈRES,
/// empilées et de plus en plus courtes vers le haut : chaque couche floute
/// ce que la précédente a déjà flouté, donc le flou s'accumule sans marche
/// visible (retour de Paul du 12/09 : la démarcation se voyait avec six
/// couches fortes). Le voile déborde sous l'en-tête ([debord]) : le flou
/// commence à zéro AVANT que la bulle n'arrive sous Louane. Un dégradé du
/// fond, lui, finit d'effacer tout en haut.
class _VoileEnTete extends StatelessWidget {
  final double hautStatut;
  final Widget child;

  const _VoileEnTete({required this.hautStatut, required this.child});

  /// Hauteur, sous l'en-tête, où le flou commence en douceur. Le fil
  /// commence en dessous : rien n'est flou tant qu'on n'a pas remonté.
  static const double debord = 44;

  /// Sigmas des couches, de la plus longue (tout le voile, à peine floue) à
  /// la plus courte (le haut, sous l'heure). Cumulé au sommet ≈ 24.
  static const _sigmas = [
    0.8, 1.0, 1.2, 1.5, 1.8, 2.2, 2.8, 3.5, 4.5, 6.0, 8.0, 10.0, 12.0, 14.0,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: -debord,
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, c) {
                final n = _sigmas.length;
                return Stack(
                  children: [
                    for (var i = 0; i < n; i++)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        // De 100 % du voile (avec le débord) à ~15 % : une
                        // marche tous les ~10 points, chacune à peine plus
                        // floue que la précédente.
                        height: c.maxHeight * (1.0 - i * (0.85 / (n - 1))),
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: _sigmas[i],
                              sigmaY: _sigmas[i],
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        // Le fondu vers le fond : presque opaque sous l'heure, transparent
        // au bas de l'en-tête (le débord en dessous n'a que du flou).
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    LouanePalette.fondChat.withValues(alpha: 0.97),
                    LouanePalette.fondChat.withValues(alpha: 0.8),
                    LouanePalette.fondChat.withValues(alpha: 0.45),
                    LouanePalette.fondChat.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.3, 0.65, 1.0],
                ),
              ),
            ),
          ),
        ),
        Padding(padding: EdgeInsets.only(top: hautStatut), child: child),
      ],
    );
  }
}

/// Petit bouton rond de l'en-tête, façon Instagram : disque translucide,
/// liseré fin, icône blanche.
class _BoutonRond extends StatelessWidget {
  final Widget enfant;
  final String libelle;
  final VoidCallback? onTap;

  const _BoutonRond({
    required this.enfant,
    required this.libelle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: libelle,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Center(child: enfant),
          ),
        ),
      ),
    );
  }
}

// ── Fine ligne de date en tête de fil ─────────────────────
/// « Aujourd'hui 14:20 », façon iMessage : la conversation repart à chaque
/// session, la ligne l'ancre dans le moment présent. Même style que les
/// lignes système du fil.
class _LigneDate extends StatelessWidget {
  final DateTime ouverture;

  const _LigneDate({required this.ouverture});

  @override
  Widget build(BuildContext context) {
    final heure =
        '${ouverture.hour.toString().padLeft(2, '0')}:'
        '${ouverture.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 14),
      child: Center(
        child: Text(
          "Aujourd'hui $heure",
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.35),
            letterSpacing: 0.2,
          ),
        ),
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
  /// Révélation de la barre de navigation (0 rentrée → 1 sortie) : la
  /// pilule garde un peu plus d'air quand la barre est rentrée.
  final double revelationNav;
  final VoidCallback onEnvoyer;

  /// Un message envoyé est en cours de modification : bandeau au-dessus du
  /// champ, avec « Annuler ». [suiteRemplacee] : il y a des messages après
  /// lui, ils disparaîtront à l'envoi.
  final bool modification;
  final bool suiteRemplacee;
  final VoidCallback onAnnulerModification;
  final bool enregistre;
  final bool enPause;
  final int secondes;
  final ValueNotifier<DateTime?> dernierMot;
  /// Appui sur le micro : la dictée.
  final VoidCallback onDictee;
  final VoidCallback onPause;
  final VoidCallback onReprendre;
  final VoidCallback onTerminer;
  final VoidCallback onAnnuler;

  const _BarreSaisie({
    required this.controller,
    required this.focusNode,
    required this.revelationNav,
    required this.onEnvoyer,
    this.modification = false,
    this.suiteRemplacee = false,
    required this.onAnnulerModification,
    required this.enregistre,
    required this.enPause,
    required this.secondes,
    required this.dernierMot,
    required this.onDictee,
    required this.onPause,
    required this.onReprendre,
    required this.onTerminer,
    required this.onAnnuler,
  });

  @override
  Widget build(BuildContext context) {
    // Pilule de verre assortie à la barre de navigation flottante : mêmes
    // marges, pas de liseré, pas de trait de jonction (retour de Paul :
    // collées avec un trait, c'était moche). Trois cas pour la marge basse
    // (MediaQuery.padding.bottom suit la barre de nav via extendBody) :
    // clavier ouvert → 6 au-dessus du clavier (le Scaffold remonte déjà le
    // corps) ; barre visible → 14 pour qu'elles ne se collent pas ; pilule
    // seule → 40 pour qu'elle respire au-dessus du bord de l'iPhone (26
    // depuis les retours de Paul du 28/08 ; « un peu basse », remontée le
    // 23/09). View.of : les VRAIS insets de la fenêtre — le Scaffold a
    // déjà consommé viewInsets dans le MediaQuery du corps.
    final clavierOuvert = View.of(context).viewInsets.bottom > 0;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(
        20,
        6,
        20,
        MediaQuery.paddingOf(context).bottom +
            (clavierOuvert ? 6 : 40 - 26 * revelationNav),
      ),
      child: _pilule(context),
    );
  }

  Widget _pilule(BuildContext context) {
    // Voile bleu nuit sur flou appuyé — la teinte exacte vient de Paul
    // (28/08), un poil plus claire que le fond de page pour que le champ
    // se démarque. Liseré discret remis le 30/08 (retour de Paul : sans
    // bordure, la pilule se confond avec les bulles de Louane, qui ont
    // quasiment la même teinte).
    // Le verre d'Apple (iOS 26) sous la pilule (Paul, 22/09/2026) : le fil
    // se voit au travers, clair et flouté, comme la barre de Claude.
    return VerreApple(
      rayon: 28,
      child: Padding(
          padding: const EdgeInsets.all(6),
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
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (modification)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 6, 4, 0),
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded,
                                size: 14,
                                color: LouanePalette.accent.withValues(alpha: 0.9)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                suiteRemplacee
                                    ? 'Modifier · la suite de la discussion sera remplacée'
                                    : 'Modifier le message',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.62),
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: onAnnulerModification,
                              tooltip: 'Annuler la modification',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints.tightFor(
                                  width: 32, height: 32),
                              icon: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ),
                    Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        minLines: 1,
                        maxLines: 4,
                        // Le serveur refuse au-delà de 2 000 caractères
                        // (audit du 02/09/2026) : on coupe ici, sans compteur.
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(2000),
                        ],
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
                          modification: modification,
                          onTap: aTexte ? onEnvoyer : onDictee,
                        );
                      },
                    ),
                  ],
                ),
                  ],
                ),
      ),
    );
  }
}

/// Le bouton à droite : micro (champ vide) ↔ envoyer (dès qu'on écrit).
class _BoutonAction extends StatelessWidget {
  final bool aTexte;

  /// Un message envoyé est en cours de modification : le bouton devient
  /// une coche (« valider »), pas une flèche.
  final bool modification;
  final VoidCallback onTap;

  const _BoutonAction({
    required this.aTexte,
    this.modification = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: Container(
          key: ValueKey(aTexte ? (modification ? 'ok' : 'envoi') : 'micro'),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: aTexte ? LouanePalette.accent : AppColors.cardSurface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            aTexte
                ? (modification ? Icons.check_rounded : Icons.arrow_upward_rounded)
                : Icons.mic_none_rounded,
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
