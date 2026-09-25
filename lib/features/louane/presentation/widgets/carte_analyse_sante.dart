import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../../../core/services/health_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/ui/apple_health_icon.dart';
import '../../../../core/ui/pouls_haptique.dart';
import '../louane_palette.dart';
import 'louane_avatar.dart';

/// Le POPUP « Louane analyse ton questionnaire Santé », qui sort du chat
/// quand le serveur pose le marqueur [ANALYSE] : le fond se floute, une carte
/// centrée montre le questionnaire balayé par un faisceau, un titre par
/// étape, trois points qui se cochent. Format repris de l'écran d'analyse de
/// l'app Blow Up (captures de Paul, 11-12/09), couleurs Quieto.
///
/// La chose analysée, c'est LE VRAI QUESTIONNAIRE de Santé (demande de Paul,
/// 12/09) : le titre, la grande question, puis les questions qui défilent
/// dans le design d'Apple, avec SES réponses à elle qui se cochent une à une
/// pendant que le scanner balaye.
///
/// Tout se déduit de [debut] (l'instant d'apparition) : le popup se ferme
/// tout seul à la fin du moment, et le fil de Louane enchaîne ses bulles.
/// Dans le fil, il ne reste qu'une fine ligne (voir [libelleAnalyse]).
class PopupAnalyseSante extends StatefulWidget {
  final AnalyseSante analyse;
  final DateTime debut;

  /// L'emplacement réservé au-dessus de la carte où l'avatar de Louane vient
  /// se poser (mesuré par [montrerAnalyseSante] pour animer le vol).
  final GlobalKey? cleCible;

  const PopupAnalyseSante({
    super.key,
    required this.analyse,
    required this.debut,
    this.cleCible,
  });

  @override
  State<PopupAnalyseSante> createState() => _PopupAnalyseSanteState();
}

/// Taille de l'avatar de Louane quand il réfléchit au-dessus du popup.
const double kTailleAvatarAnalyse = 68;

/// Durée du vol de l'avatar (aller comme retour) = durée de la transition.
/// Long et progressif (retour de Paul, 12/09 : « tous les gestes doux ») :
/// part lentement, va plus vite au milieu, se pose lentement.
const Duration kDureeVolAvatar = Duration(milliseconds: 1100);

/// Ouvre le popup par-dessus TOUTE l'app (navigateur racine : la barre de
/// navigation aussi passe sous le flou) et le laisse se fermer tout seul.
///
/// [origine] : le rectangle (coordonnées écran) de l'avatar de Louane dans
/// l'en-tête du chat. S'il est donné, l'avatar VOLE de là jusqu'au-dessus de
/// la carte (plus gros, net, par-dessus le flou), y réfléchit pendant
/// l'analyse, et revient à sa place à la fermeture. L'appelant cache
/// l'avatar de l'en-tête pendant ce temps (louaneAvatarEnVolProvider).
Future<void> montrerAnalyseSante(
  BuildContext context, {
  required AnalyseSante analyse,
  required DateTime debut,
  Rect? origine,
}) {
  FocusManager.instance.primaryFocus?.unfocus();
  final cleCible = GlobalKey();

  /// Où l'avatar se pose : l'emplacement réservé, une fois mis en page ;
  /// avant, l'origine (première image de la transition).
  Rect cible() {
    final boite = cleCible.currentContext?.findRenderObject();
    if (boite is RenderBox && boite.attached && boite.hasSize) {
      return boite.localToGlobal(Offset.zero) & boite.size;
    }
    return origine ?? Rect.zero;
  }

  return showGeneralDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierLabel: 'Louane analyse ton questionnaire',
    barrierColor: Colors.transparent,
    transitionDuration: kDureeVolAvatar,
    pageBuilder: (_, _, _) => PopupAnalyseSante(
      analyse: analyse,
      debut: debut,
      cleCible: cleCible,
    ),
    transitionBuilder: (_, anim, _, child) {
      // Le vol : trajectoire en arc léger, taille qui grandit, courbe en
      // sinus (la plus douce aux deux bouts), à l'aller comme au retour
      // (anim rejoue 1 → 0 à la fermeture).
      final tVol = Curves.easeInOutSine.transform(anim.value);
      // La carte et le flou suivent EXACTEMENT le vol (retour de Paul,
      // 12/09) : le popup commence à s'effacer quand Louane décolle, et a
      // disparu pile quand elle se pose dans l'en-tête. Même chose à l'aller.
      final t = tVol;
      // À l'ouverture seulement, la carte se pose avec un léger rebond.
      final echelle = anim.status == AnimationStatus.forward
          ? Curves.easeOutBack.transform(anim.value)
          : t;
      Widget? avatar;
      if (origine != null) {
        final arrivee = cible();
        final centre = Offset.lerp(origine.center, arrivee.center, tVol)! +
            Offset(0, -30 * math.sin(math.pi * tVol));
        final taille = ui.lerpDouble(origine.width, arrivee.width, tVol)!;
        avatar = Positioned(
          left: centre.dx - taille / 2,
          top: centre.dy - taille / 2,
          child: DecoratedBox(
            // Une ombre douce sous elle : elle est devant, pas collée.
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: LouaneAvatar(size: taille, parle: true),
          ),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          // Le chat derrière se floute et s'assombrit.
          BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.6 * t),
            ),
          ),
          Opacity(
            opacity: t,
            child: Transform.scale(
              scale: 0.93 + 0.07 * echelle,
              child: child,
            ),
          ),
          // Louane, nette, par-dessus tout : c'est elle qui réfléchit.
          ?avatar,
        ],
      );
    },
  );
}

/// La fine ligne qui reste dans le fil une fois le popup refermé. Les trois
/// tests de Santé nommés sans ambiguïté (demande de Paul, 12/09) : anxiété,
/// dépression, ou le questionnaire complet de bien-être mental.
String libelleAnalyse(AnalyseSante analyse) => switch (analyse.test) {
      TestSante.anxiete => "Louane a lu ton questionnaire sur l'anxiété",
      TestSante.humeur => 'Louane a lu ton questionnaire sur la dépression',
      TestSante.complet =>
        'Louane a lu ton questionnaire de bien-être mental',
    };

/// Une étape : le mot sous le point, le titre au-dessus (première personne,
/// comme l'écran de création du programme).
class _Etape {
  final String label;
  final String titre;
  const _Etape(this.label, this.titre);
}

List<_Etape> _etapesPour(TestSante test) {
  final quoi = switch (test) {
    TestSante.anxiete => "ton questionnaire sur l'anxiété",
    TestSante.humeur => 'ton questionnaire sur la dépression',
    TestSante.complet => 'ton questionnaire de bien-être mental',
  };
  return [
    _Etape('Lecture', 'Je lis $quoi'),
    _Etape('Liens', "Je relie ça à ce que tu m'as confié"),
    _Etape('Synthèse', 'Je prépare ce que je vais te dire'),
  ];
}

/// Le nom du test tel que Santé l'affiche (c'est l'étiquette de la scène,
/// pas la voix de Louane).
String _nomSante(TestSante test) => switch (test) {
      TestSante.anxiete => 'Questionnaire anxiété',
      TestSante.humeur => 'Questionnaire dépression',
      TestSante.complet => 'Questionnaire sur la santé mentale',
    };

// ── Métriques de la scène (mise en page FIXE : le défilement se calcule) ──
const double _hScene = 270;
const double _padScene = 14;
const double _hTitre = 96; // petit titre + grande question (3 lignes)
const double _hEnTeteCarte = 66; // « Question N sur T » + libellé (2 lignes)
const double _hChoix = 27; // une ligne de réponse
const double _hBasCarte = 6;
const double _ecartCartes = 10;
const double _basContenu = 24;
double _hCarte(QuestionAnalyse q) =>
    _hEnTeteCarte + _hChoix * q.nbChoix + _hBasCarte;

// Design Apple Santé (feuille du questionnaire), tel que sur les captures.
const _fondSante = Color(0xFF151517);
const _carteSante = Color(0xFF2A2A2D);
const _texteSecondaireSante = Color(0xFF9A9AA0);
const _bleuSante = Color(0xFF0A84FF);

class _PopupAnalyseSanteState extends State<PopupAnalyseSante>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;

  /// Tourne en continu : l'orbite autour du point actif, et le rafraîchissement
  /// des ondes quand une étape se coche.
  late final AnimationController _orbite;
  late final Ticker _ticker;
  final _scroll = ScrollController();

  /// Avancement CONTINU sur la ligne de progression (0 → 1 sur les trois
  /// étapes) : la tête lumineuse glisse sans à-coup, les points s'allument
  /// quand elle les atteint.
  final _avancement = ValueNotifier<double>(0);

  /// Ce que Louane est en train de faire, en une ligne qui bouge : la
  /// réponse qu'elle lit, ce qu'elle relie, les mots qu'elle choisit.
  final _statut = ValueNotifier<String>('Je lis tes réponses');

  /// Instant où chaque point s'est coché → une onde s'en échappe.
  final List<DateTime?> _ondes = [null, null, null];

  /// Le pouls de l'analyse : des impulsions de plus en plus rapprochées et
  /// fortes à mesure qu'elle avance, puis un coup franc à la fin (Paul, 12/09).
  final _pouls = PoulsHaptique();
  bool _vibrationFinaleFaite = false;

  /// Position du faisceau dans la scène (null = caché). Notifier, pas
  /// setState : le faisceau bouge à chaque image, le reste non.
  final _faisceauY = ValueNotifier<double?>(null);

  late final List<QuestionAnalyse> _questions = widget.analyse.questions;
  late final List<double> _hautsCartes = _calculerHauts();

  int _etape = 0; // 0..2, 3 = terminé
  int _nbCochees = 0; // questions dont la réponse est déjà cochée

  AnalyseSante get _a => widget.analyse;
  Duration get _ecoule => DateTime.now().difference(widget.debut);

  List<double> _calculerHauts() {
    final hauts = <double>[];
    var y = _hTitre;
    for (final q in _questions) {
      hauts.add(y);
      y += _hCarte(q) + _ecartCartes;
    }
    return hauts;
  }

  double get _hContenu =>
      (_hautsCartes.isEmpty ? _hTitre : _hautsCartes.last +
          _hCarte(_questions.last)) + _basContenu;

  /// Décalage de défilement visé pour lire la question [i] (-1 = le titre).
  double _cible(int i) {
    if (i < 0) return 0;
    final max = math.max(0.0, _hContenu - _hScene);
    return (_hautsCartes[i] - 10).clamp(0.0, max);
  }

  int _etapePour(Duration e) {
    if (e >= _a.duree) return 3;
    if (e >= _a.dureeLecture + AnalyseSante.dureeLiens) return 2;
    if (e >= _a.dureeLecture) return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    final ecoule = _ecoule;
    _etape = _etapePour(ecoule);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _orbite = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _ticker = createTicker((_) => _image());
    if (_etape < 3) {
      _pulse.repeat(reverse: true);
      _ticker.start();
    } else {
      // Ouvert alors que le moment est déjà passé : on referme aussitôt.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fermer());
    }
  }

  bool _fermetureLancee = false;

  /// Fin du moment : un dernier temps de pose sur « Questionnaire analysé »,
  /// puis le popup s'efface et le fil reprend la main.
  void _fermer() {
    if (_fermetureLancee) return;
    _fermetureLancee = true;
    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).maybePop();
    });
  }

  void _defiler(double offset) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(offset.clamp(0.0, max));
  }

  /// Profil de vitesse « trapèze » : une montée douce, une vitesse constante,
  /// une descente douce. Position normalisée (0 → 1) pour un temps [t] 0 → 1.
  /// Plus fluide qu'un ease-in-out (qui accélère trop au milieu).
  static double _profil(double t, {double r = 0.16}) {
    final aire = 1 - r;
    double pos;
    if (t < r) {
      pos = t * t / (2 * r);
    } else if (t < 1 - r) {
      pos = r / 2 + (t - r);
    } else {
      final u = 1 - t;
      pos = aire - u * u / (2 * r);
    }
    return (pos / aire).clamp(0.0, 1.0);
  }

  /// Ligne de lecture : une réponse est cochée quand elle passe au-dessus
  /// (retour de Paul du 12/09 : plus de saut sur chaque réponse, le
  /// questionnaire glisse et les coches suivent).
  static const double _ligneLecture = _hScene * 0.55;

  /// Une image : où en est le défilement, où est le scanner, quoi cocher.
  void _image() {
    if (!mounted) return;
    final ecoule = _ecoule;
    final etape = _etapePour(ecoule);
    final n = _questions.length;

    // Défilement CONTINU et doux du titre jusqu'à la dernière question, sur
    // toute la durée de lecture (après la pose sur le titre).
    final lectureMs = (_a.dureeLecture - AnalyseSante.dureeIntro).inMilliseconds;
    final tLecture = etape > 0
        ? 1.0
        : ((ecoule - AnalyseSante.dureeIntro).inMilliseconds / lectureMs)
            .clamp(0.0, 1.0);
    final offset = _cible(n - 1) * _profil(tLecture);
    _defiler(offset);

    // Le scanner : un aller-retour de haut en bas, lent, qui ralentit
    // progressivement aux deux bouts (sinus), sans lien avec les réponses,
    // tant que l'analyse tourne.
    if (etape < 3) {
      const periodeMs = 5200.0;
      final phase = (ecoule.inMilliseconds % periodeMs) / periodeMs;
      const marge = 14.0;
      _faisceauY.value = marge +
          (_hScene - 2 * marge) * (0.5 - 0.5 * math.cos(2 * math.pi * phase));
    } else {
      _faisceauY.value = null;
    }

    // Coches : chaque réponse se coche quand elle passe la ligne de lecture ;
    // en fin de lecture, tout est coché quoi qu'il arrive.
    var cochees = 0;
    if (tLecture >= 1) {
      cochees = n;
    } else {
      for (var i = 0; i < n; i++) {
        final yReponse = _hautsCartes[i] -
            offset +
            _hEnTeteCarte +
            _hChoix * _questions[i].reponse +
            _hChoix / 2;
        if (yReponse <= _ligneLecture) cochees = i + 1;
      }
    }

    // Avancement continu de la tête lumineuse : chaque étape occupe un
    // tiers de la ligne, parcouru au rythme de sa propre durée.
    final ecouleMs = ecoule.inMilliseconds;
    final lectureMsTotal = _a.dureeLecture.inMilliseconds;
    final liensMs = AnalyseSante.dureeLiens.inMilliseconds;
    final syntheseMs = AnalyseSante.dureeSynthese.inMilliseconds;
    double avancement;
    if (etape >= 3) {
      avancement = 1;
    } else {
      final debuts = [0, lectureMsTotal, lectureMsTotal + liensMs];
      final durees = [lectureMsTotal, liensMs, syntheseMs];
      final dans = ((ecouleMs - debuts[etape]) / durees[etape]).clamp(0.0, 1.0);
      avancement = (etape + dans) / 3;
    }
    _avancement.value = avancement;

    // La ligne de statut : ce qu'elle fait, là, maintenant.
    _statut.value = switch (etape) {
      0 => cochees == 0
          ? 'Je lis tes réponses'
          : 'Réponse $cochees sur $n · '
              '${_libelleChoix(_questions[cochees - 1])}',
      1 => 'Avec ${const [
          "ce que tu m'as raconté",
          'ton profil Quieto',
          'tes autres signaux Santé',
        ][((ecouleMs - lectureMsTotal) ~/ (liensMs ~/ 3)).clamp(0, 2)]}',
      2 => 'Je choisis mes mots${'.' * (1 + (ecouleMs ~/ 380) % 3)}',
      _ => "C'est bon, je t'écris",
    };

    if (etape < 3) {
      _pouls.avancer(avancement);
    } else if (!_vibrationFinaleFaite) {
      _vibrationFinaleFaite = true;
      PoulsHaptique.arrivee();
    }

    final changementEtape = etape != _etape;
    if (cochees != _nbCochees || changementEtape) {
      if (changementEtape) {
        // Le point qui vient de se cocher lâche une onde.
        for (var i = _etape; i < etape && i < 3; i++) {
          _ondes[i] = DateTime.now();
        }
      }
      setState(() {
        _nbCochees = cochees;
        _etape = etape;
      });
    }
    if (etape >= 3) {
      _ticker.stop();
      _pulse.stop();
      _fermer();
    }
  }

  String _libelleChoix(QuestionAnalyse q) => q.reponse == 4
      ? kChoixPasRepondre
      : kChoixQuestionnaireSante[q.reponse.clamp(0, 3)];

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    _orbite.dispose();
    _scroll.dispose();
    _faisceauY.dispose();
    _avancement.dispose();
    _statut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etapes = _etapesPour(_a.test);
    final termine = _etape >= 3;
    final titre = termine ? 'Questionnaire analysé' : etapes[_etape].titre;
    final largeur = math.min(326.0, MediaQuery.sizeOf(context).width - 64);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // L'emplacement de Louane, au-dessus de la carte : l'avatar qui
            // vole depuis l'en-tête vient se poser exactement ici.
            SizedBox(
              key: widget.cleCible,
              width: kTailleAvatarAnalyse,
              height: kTailleAvatarAnalyse,
            ),
            const SizedBox(height: 14),
            Container(
          width: largeur,
          clipBehavior: Clip.antiAlias,
          // Bien démarqué du fond flouté (retour de Paul, 12/09) : carte un
          // peu plus claire que le fond, bordure claire visible, fin halo
          // turquoise autour, ombre portée en dessous.
          decoration: BoxDecoration(
            color: const Color(0xFF12294A),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: LouanePalette.accent.withValues(alpha: 0.16),
                blurRadius: 28,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          // La bordure au PREMIER PLAN : peinte par-dessus la scène, elle
          // fait tout le tour, coins arrondis du haut compris (dessous, la
          // scène la recouvrait dans les angles).
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  _scene(termine),
                  // Reflet fin sur le haut de la carte : la lumière vient
                  // d'en haut, comme sur un verre.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.45),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Fin liseré lumineux entre la scène et le bas de la carte.
              Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      LouanePalette.accent.withValues(alpha: 0),
                      LouanePalette.accent.withValues(alpha: 0.55),
                      LouanePalette.accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Le titre de l'étape glisse vers le haut en fondu :
                    // l'ancien s'efface, le nouveau monte prendre sa place.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 460),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        titre,
                        key: ValueKey(titre),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.25,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Ce qu'elle fait, là, maintenant : change en fondu.
                    SizedBox(
                      height: 18,
                      child: ValueListenableBuilder<String>(
                        valueListenable: _statut,
                        builder: (context, statut, _) => AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            statut,
                            key: ValueKey(statut),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: LouanePalette.accent.withValues(alpha: 0.9),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _Progression(
                      etapes: etapes,
                      etape: _etape,
                      avancement: _avancement,
                      pulse: _pulse,
                      orbite: _orbite,
                      ondes: _ondes,
                    ),
                  ],
                ),
              ),
            ],
          ),
            ),
          ],
        ),
      ),
    );
  }

  // ── La scène : le questionnaire de Santé qui défile sous le faisceau ──

  Widget _scene(bool termine) {
    final n = _questions.length;
    final etiquette = _etape == 0 && !termine
        ? _nomSante(_a.test)
        : '$n réponse${n > 1 ? 's' : ''} lue${n > 1 ? 's' : ''}';
    return SizedBox(
      height: _hScene,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: _fondSante),
          // Le questionnaire, que PERSONNE ne fait défiler à la main : c'est
          // la lecture de Louane qui le fait avancer.
          IgnorePointer(
            child: SingleChildScrollView(
              controller: _scroll,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                _padScene, 0, _padScene, _basContenu),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TitreSante(),
                  for (var i = 0; i < n; i++) ...[
                    _CarteQuestion(
                      question: _questions[i],
                      cochee: i < _nbCochees,
                    ),
                    if (i < n - 1) const SizedBox(height: _ecartCartes),
                  ],
                ],
              ),
            ),
          ),
          // Voile doux en haut et en bas : le questionnaire se fond dans la
          // scène au lieu d'être coupé net.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xCC151517),
                    Color(0x00151517),
                    Color(0x00151517),
                    Color(0xB3151517),
                  ],
                  stops: [0.0, 0.18, 0.82, 1.0],
                ),
              ),
            ),
          ),
          // Faisceau + coins du cadre de lecture, par-dessus.
          IgnorePointer(
            child: ValueListenableBuilder<double?>(
              valueListenable: _faisceauY,
              builder: (context, y, _) => CustomPaint(
                painter: _CadrePainter(faisceauY: y, termine: termine),
              ),
            ),
          ),
          Positioned(
            top: 11,
            left: 0,
            right: 0,
            child: Center(child: _Pilule(texte: etiquette)),
          ),
        ],
      ),
    );
  }
}

/// Le haut de la feuille de Santé : le nom du questionnaire, puis la grande
/// question qui coiffe toutes les autres.
class _TitreSante extends StatelessWidget {
  const _TitreSante();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _hTitre,
      child: Padding(
        padding: EdgeInsets.only(top: 40),
        child: Text(
          'Au cours des 2 dernières semaines, selon quelle fréquence '
          'avez-vous été gêné(e) par les problèmes suivants ?',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// Une question comme Santé la présente : « Question N sur T », le libellé,
/// puis les choix, avec la réponse donnée qui se coche en bleu.
class _CarteQuestion extends StatelessWidget {
  final QuestionAnalyse question;
  final bool cochee;

  const _CarteQuestion({required this.question, required this.cochee});

  @override
  Widget build(BuildContext context) {
    // Toujours les quatre choix d'Apple ; la question facultative se
    // signale dans son numéro, et reste sans coche si elle a été passée.
    const choix = kChoixQuestionnaireSante;
    return Container(
      height: _hCarte(question),
      decoration: BoxDecoration(
        color: _carteSante,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${question.numero} sur ${question.total}'
            '${question.avecChoixPasRepondre ? ' (facultatif)' : ''}',
            style: const TextStyle(
              fontSize: 10.5,
              color: _texteSecondaireSante,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            height: 32,
            child: Text(
              question.libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < choix.length; i++)
            _LigneChoix(
              texte: choix[i],
              selectionnee: cochee && i == question.reponse,
              derniere: i == choix.length - 1,
            ),
        ],
      ),
    );
  }
}

class _LigneChoix extends StatelessWidget {
  final String texte;
  final bool selectionnee;
  final bool derniere;

  const _LigneChoix({
    required this.texte,
    required this.selectionnee,
    required this.derniere,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _hChoix,
      decoration: BoxDecoration(
        border: derniere
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.09),
                  width: 0.6,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texte,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: Colors.white),
            ),
          ),
          // La coche apparaît en douceur (fondu + léger agrandissement)
          // quand la réponse passe la ligne de lecture.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.6, end: 1).animate(anim),
                child: child,
              ),
            ),
            child: selectionnee
                ? Container(
                    key: const ValueKey('oui'),
                    width: 15,
                    height: 15,
                    decoration: const BoxDecoration(
                      color: _bleuSante,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  )
                : Container(
                    key: const ValueKey('non'),
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42),
                        width: 1.3,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// La petite étiquette en haut de la scène : d'où vient ce que Louane lit,
/// puis combien de réponses elle a lues.
class _Pilule extends StatelessWidget {
  final String texte;
  const _Pilule({required this.texte});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey(texte),
        padding: const EdgeInsets.fromLTRB(9, 4, 11, 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppleHealthIcon(size: 12),
            const SizedBox(width: 6),
            Text(
              texte,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les coins du cadre de lecture, et le faisceau turquoise qui balaye la
/// feuille de haut en bas, comme un scanner, tant que l'analyse tourne.
class _CadrePainter extends CustomPainter {
  final double? faisceauY;
  final bool termine;

  const _CadrePainter({required this.faisceauY, required this.termine});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final y = faisceauY;
    if (y != null) {
      // Le faisceau est plus fort au centre qu'aux bords : chaque couche
      // porte un dégradé horizontal (transparent → plein → transparent).
      ui.Shader horizontal(Color c, double alpha) => ui.Gradient.linear(
            Offset(0, y),
            Offset(w, y),
            [
              c.withValues(alpha: 0),
              c.withValues(alpha: alpha),
              c.withValues(alpha: alpha),
              c.withValues(alpha: 0),
            ],
            const [0.0, 0.22, 0.78, 1.0],
          );
      // 1. Le halo turquoise, large et très flou.
      canvas.drawRect(
        Rect.fromLTRB(-20, y - 26, w + 20, y + 26),
        Paint()
          ..shader = horizontal(LouanePalette.accent, 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
      );
      // 2. La bande blanche, moyenne, floue : c'est elle qui « flashe ».
      canvas.drawRect(
        Rect.fromLTRB(-10, y - 7, w + 10, y + 7),
        Paint()
          ..shader = horizontal(Colors.white, 0.62)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
      );
      // 3. Le cœur : un trait vif, presque net.
      canvas.drawRect(
        Rect.fromLTRB(0, y - 1.4, w, y + 1.4),
        Paint()
          ..shader = horizontal(Colors.white, 0.98)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    final coin = Paint()
      ..color = Colors.white.withValues(alpha: termine ? 0.22 : 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Bien rentrés (retour de Paul, 12/09) : loin des coins arrondis du
    // popup, qu'ils touchaient.
    const inset = 22.0;
    const long = 18.0;
    void coinL(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(long * dx, 0), coin);
      canvas.drawLine(o, o + Offset(0, long * dy), coin);
    }

    coinL(const Offset(inset, inset), 1, 1);
    coinL(Offset(w - inset, inset), -1, 1);
    coinL(Offset(inset, h - inset), 1, -1);
    coinL(Offset(w - inset, h - inset), -1, -1);
  }

  @override
  bool shouldRepaint(_CadrePainter old) =>
      old.faisceauY != faisceauY || old.termine != termine;
}

// ── La ligne de progression : trois points, trois mots ──
// Repeinte le 12/09 (retour de Paul : « trop simple, pas assez fluide ») :
// le remplissage glisse en continu avec une tête lumineuse qui respire, le
// point actif porte une orbite qui tourne, chaque point coché lâche une onde.

class _Progression extends StatelessWidget {
  final List<_Etape> etapes;
  final int etape; // index courant, 3 = tout coché
  final ValueListenable<double> avancement;
  final Animation<double> pulse;
  final Animation<double> orbite;
  final List<DateTime?> ondes;

  const _Progression({
    required this.etapes,
    required this.etape,
    required this.avancement,
    required this.pulse,
    required this.orbite,
    required this.ondes,
  });

  Widget _point(int i) {
    final fait = etape >= 3 || i < etape;
    final actif = !fait && i == etape;
    final Widget point;
    if (fait) {
      point = Container(
        key: const ValueKey('fait'),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: LouanePalette.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: LouanePalette.accent.withValues(alpha: 0.45),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 15,
          color: AppColors.background,
        ),
      );
    } else if (actif) {
      final t = pulse.value;
      point = Container(
        key: const ValueKey('actif'),
        width: 12 + 2 * t,
        height: 12 + 2 * t,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: LouanePalette.accent.withValues(alpha: 0.6 + 0.25 * t),
              blurRadius: 10 + 6 * t,
              spreadRadius: 1 + t,
            ),
          ],
        ),
      );
    } else {
      point = Container(
        key: const ValueKey('attente'),
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.26),
          shape: BoxShape.circle,
        ),
      );
    }
    // Un point qui passe à « fait » rebondit un peu (comme les coches de
    // l'écran de création du programme).
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: point,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final n = etapes.length;
          final xs = List.generate(n, (i) => w * (0.16 + 0.68 * i / (n - 1)));
          const yPoint = 12.0;
          return AnimatedBuilder(
            animation: Listenable.merge([avancement, pulse, orbite]),
            builder: (context, _) {
              final maintenant = DateTime.now();
              final ondesT = ondes.map((d) {
                if (d == null) return null;
                final t = maintenant.difference(d).inMilliseconds / 700;
                return t >= 1 ? null : t;
              }).toList();
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LigneProgresPainter(
                        xs: xs,
                        y: yPoint,
                        avancement: avancement.value,
                        etape: etape,
                        pulse: pulse.value,
                        orbite: orbite.value,
                        ondes: ondesT,
                      ),
                    ),
                  ),
                  for (var i = 0; i < n; i++) ...[
                    Positioned(
                      left: xs[i] - 12,
                      top: yPoint - 12,
                      width: 24,
                      height: 24,
                      child: Center(child: _point(i)),
                    ),
                    Positioned(
                      left: xs[i] - 48,
                      top: 32,
                      width: 96,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 360),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              i == etape ? FontWeight.w600 : FontWeight.w500,
                          color: Colors.white.withValues(
                            alpha: etape >= 3 || i < etape
                                ? 0.65
                                : i == etape
                                    ? 1.0
                                    : 0.35,
                          ),
                        ),
                        child: Text(
                          etapes[i].label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Le dessin sous les points : le rail, le remplissage qui avance, la tête
/// lumineuse, l'orbite du point actif et les ondes des points cochés.
class _LigneProgresPainter extends CustomPainter {
  final List<double> xs;
  final double y;
  final double avancement;
  final int etape;
  final double pulse;
  final double orbite;
  final List<double?> ondes;

  const _LigneProgresPainter({
    required this.xs,
    required this.y,
    required this.avancement,
    required this.etape,
    required this.pulse,
    required this.orbite,
    required this.ondes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accent = LouanePalette.accent;
    final x0 = xs.first;
    final x1 = xs.last;
    final xTete = x0 + (x1 - x0) * avancement;

    // Le rail.
    canvas.drawLine(
      Offset(x0, y),
      Offset(x1, y),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Le remplissage, plus vif vers la tête.
    if (xTete > x0) {
      canvas.drawLine(
        Offset(x0, y),
        Offset(xTete, y),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x0, y),
            Offset(xTete, y),
            [accent.withValues(alpha: 0.55), accent],
          )
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    }

    // La tête lumineuse, qui respire, et sa traînée devant elle.
    if (etape < 3) {
      canvas.drawCircle(
        Offset(xTete, y),
        14 + 4 * pulse,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(xTete, y),
            14 + 4 * pulse,
            [accent.withValues(alpha: 0.5 + 0.2 * pulse), accent.withValues(alpha: 0)],
          ),
      );
      canvas.drawLine(
        Offset(xTete, y),
        Offset(math.min(x1, xTete + 26), y),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(xTete, y),
            Offset(xTete + 26, y),
            [accent.withValues(alpha: 0.45), accent.withValues(alpha: 0)],
          )
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(xTete, y),
        2.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );

      // L'orbite du point actif : un arc qui tourne, avec une traîne.
      final centre = Offset(xs[etape], y);
      const rayon = 15.0;
      final depart = orbite * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: rayon),
        depart,
        1.25,
        false,
        Paint()
          ..color = accent.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: rayon),
        depart - 1.4,
        1.4,
        false,
        Paint()
          ..color = accent.withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // Les ondes : un anneau qui s'élargit et s'efface depuis le point coché.
    for (var i = 0; i < ondes.length && i < xs.length; i++) {
      final t = ondes[i];
      if (t == null) continue;
      final e = Curves.easeOut.transform(t);
      canvas.drawCircle(
        Offset(xs[i], y),
        11 + 22 * e,
        Paint()
          ..color = accent.withValues(alpha: 0.6 * (1 - e))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + 1.5 * (1 - e),
      );
    }
  }

  @override
  bool shouldRepaint(_LigneProgresPainter old) => true;
}
