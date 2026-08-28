import 'dart:io' show File;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/parcours_model.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/starry_background.dart';
import '../../home/presentation/widgets/night_sky_header.dart';
import '../../louane/louane_providers.dart';
import '../../louane/presentation/widgets/louane_avatar.dart';
import '../../onboarding/presentation/widgets/slide_reveal.dart';
import '../../player/player_providers.dart';
import '../parcours_providers.dart';
import 'widgets/carte_partage_parcours.dart';
import 'widgets/constellation_etat.dart';
import 'widgets/constellation_reveal.dart';

/// Les ressentis proposés au bilan de fin de semaine. Textes en dur :
/// pas d'emoji, pas de tiret long. Public pour le test de style.
const List<String> kRessentisBilan = [
  'Apaisé(e)',
  "Mieux qu'avant",
  'Pareil',
  'Fatigué(e)',
  'Fier(e) de moi',
];

/// Les trois temps de l'arrivée depuis la création : la constellation se
/// dessine au centre, monte se poser en haut, puis le contenu se révèle.
/// Un tap pendant le dessin saute l'arrivée.
enum _PhaseArrivee { dessin, montee, pose }

/// Le programme de 7 jours, version « chemin d'étoiles » : la constellation
/// de la semaine en hero, puis une timeline verticale qui descend, une étoile
/// par jour. Le jour d'aujourd'hui a une grande carte lumineuse (cover +
/// bulle de Louane + bouton), les jours faits brillent en compact, les jours
/// à venir attendent, estompés et sans dévoiler le mot de Louane.
///
/// [depuisCreation] : juste après la génération, la page joue la révélation
/// (constellation dessinée au centre → montée vers le hero → cascade).
class ParcoursPage extends ConsumerStatefulWidget {
  final bool depuisCreation;

  const ParcoursPage({super.key, this.depuisCreation = false});

  @override
  ConsumerState<ParcoursPage> createState() => _ParcoursPageState();
}

class _ParcoursPageState extends ConsumerState<ParcoursPage> {
  /// Jours terminés dont la carte est dépliée (mot de Louane + Réécouter).
  final Set<int> _deplies = {};
  String? _ressenti;
  final _texteBilan = TextEditingController();
  bool _bilanEnvoye = false;

  _PhaseArrivee _arrivee = _PhaseArrivee.pose;
  bool _overlaySurScene = false; // la constellation voyageuse est à l'écran
  final _cleHero = GlobalKey();
  final _cleScene = GlobalKey();
  Rect? _rectCible;

  /// Étoile fraîchement gagnée à célébrer (allumage + vibration), une fois.
  int? _jourACelebrer;

  // La carte de partage : montée hors champ le temps de la capture.
  final _cleCarte = GlobalKey();
  bool _carteMontee = false;
  bool _partageEnCours = false;

  @override
  void initState() {
    super.initState();
    if (widget.depuisCreation) {
      _arrivee = _PhaseArrivee.dessin;
      _overlaySurScene = true;
    }
    // Séance du jour finie depuis la dernière visite (retour du player,
    // ou réouverture de l'app) : l'étoile s'allumera à l'affichage.
    _detecterCelebration(ref.read(parcoursProvider), notifie: false);
    ref.read(vigieProvider).log('parcours_ouvert');
  }

  /// Compare les jours faits au dernier décompte célébré : s'il y a du
  /// nouveau, l'étoile du dernier jour fait s'allume (une seule fois,
  /// persisté tout de suite pour ne jamais rejouer).
  void _detecterCelebration(ParcoursModel? parcours, {required bool notifie}) {
    if (parcours == null) return;
    final faits = parcours.joursTermines.length;
    final storage = ref.read(storageServiceProvider);
    if (faits <= 0 || faits <= storage.parcoursEtoilesCelebrees) return;
    storage.setParcoursEtoilesCelebrees(faits);
    if (notifie) {
      setState(() => _jourACelebrer = faits);
    } else {
      _jourACelebrer = faits;
    }
  }

  /// Capture la carte story (1080 x 1920) et ouvre la feuille de partage.
  /// La carte est montée hors champ le temps du rendu, puis démontée.
  Future<void> _partagerCarte() async {
    if (_partageEnCours) return;
    _partageEnCours = true;
    ref.read(vigieProvider).log('parcours_partage');
    try {
      setState(() => _carteMontee = true);
      // La carte doit avoir été peinte au moins une fois avant la capture.
      await WidgetsBinding.instance.endOfFrame;
      final frontiere = _cleCarte.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (frontiere == null) return;
      final image = await frontiere.toImage(pixelRatio: 3);
      final octets = await image.toByteData(format: ui.ImageByteFormat.png);
      if (octets == null) return;
      final fichier = File(
          '${(await getTemporaryDirectory()).path}/quieto_programme.png');
      await fichier.writeAsBytes(octets.buffer.asUint8List());
      if (!mounted) return;
      // Origine du partage : obligatoire sur iPad (ancre du popover).
      final boite = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(fichier.path, mimeType: 'image/png')],
        sharePositionOrigin: boite != null
            ? boite.localToGlobal(Offset.zero) & boite.size
            : null,
      ));
    } catch (e) {
      debugPrint('[Parcours] partage échoué : $e');
    } finally {
      if (mounted) setState(() => _carteMontee = false);
      _partageEnCours = false;
    }
  }

  /// Tap pendant le dessin : on saute l'arrivée.
  void _passerArrivee() {
    if (_arrivee != _PhaseArrivee.dessin) return;
    ref.read(vigieProvider).log('parcours_arrivee_passee');
    setState(() {
      _arrivee = _PhaseArrivee.pose;
      _overlaySurScene = false;
    });
  }

  /// Le dessin est fini : on mesure la place du hero dans la page (scroll
  /// encore à zéro → position stable) et la constellation s'y envole.
  void _lancerMontee() {
    if (!mounted) return;
    final hero = _cleHero.currentContext?.findRenderObject() as RenderBox?;
    final scene = _cleScene.currentContext?.findRenderObject() as RenderBox?;
    if (hero != null && scene != null) {
      _rectCible =
          hero.localToGlobal(Offset.zero, ancestor: scene) & hero.size;
    }
    setState(() => _arrivee = _PhaseArrivee.montee);
  }

  /// Posée : la version « état » (jour 1 qui pulse) prend le relais en
  /// fondu croisé, et le reste de la page se révèle en cascade.
  void _poserConstellation() {
    if (!mounted || _arrivee != _PhaseArrivee.montee) return;
    HapticFeedback.lightImpact();
    setState(() => _arrivee = _PhaseArrivee.pose);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _overlaySurScene = false);
    });
  }

  @override
  void dispose() {
    _texteBilan.dispose();
    super.dispose();
  }

  Future<void> _confirmerAbandon() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text('Arrêter ce programme ?', style: AppTextStyles.titleMedium),
        content: Text(
          'Ta progression sera effacée. Louane pourra t\'en créer un '
          'nouveau quand tu veux.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Continuer le programme',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Arrêter',
                style:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirme == true && mounted) {
      // Une séance DU programme en cours d'écoute s'arrête avec lui (demande
      // de Paul du 28/08) — une séance du catalogue, elle, continue. On ne
      // touche au playerProvider que s'il existe déjà : le lire à froid en
      // créerait un neuf… qui relancerait l'audio (auto-play de _init).
      final actifId = ref.read(activeSessionIdProvider);
      final parcours = ref.read(parcoursProvider);
      final seanceDuParcours = actifId != null &&
          (parcours?.jours.any((j) => j.sessionId == actifId) ?? false);
      if (seanceDuParcours && ref.exists(playerProvider(actifId))) {
        await ref.read(playerProvider(actifId).notifier).stop();
        ref.read(activeSessionIdProvider.notifier).state = null;
      }
      await ref.read(parcoursProvider.notifier).abandonner();
      if (mounted) context.pop();
    }
  }

  Future<void> _envoyerBilan(ParcoursModel parcours) async {
    final ressenti = _ressenti;
    if (ressenti == null || _bilanEnvoye) return;
    setState(() => _bilanEnvoye = true);
    await ref.read(parcoursProvider.notifier).validerBilan(ressenti);
    ref
        .read(louaneChatProvider.notifier)
        .envoyerBilanParcours(ressenti, _texteBilan.text.trim());
    if (!mounted) return;
    // On rejoint Louane : sa réponse au bilan arrive dans la conversation.
    context.go(AppRoutes.louane);
  }

  @override
  Widget build(BuildContext context) {
    // Séance finie pendant que cette page attend sous le player : la
    // célébration se prépare ici et se jouera au retour (page visible).
    ref.listen(parcoursProvider,
        (_, parcours) => _detecterCelebration(parcours, notifie: true));
    final parcours = ref.watch(parcoursProvider);
    if (parcours == null) {
      // Plus de programme (abandon depuis un autre écran) : rien à montrer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return const Scaffold(backgroundColor: AppColors.background);
    }

    final aujourdHui = ParcoursModel.cleJourLocal(DateTime.now());
    final montreBilan = parcours.tousJoursTermines && !parcours.bilanFait;
    final faits = parcours.joursTermines.length;
    final pose = _arrivee == _PhaseArrivee.pose;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          // L'aurore monte derrière la constellation du hero, comme sur
          // l'accueil : le haut de page respire au lieu d'être vide.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: AuroraSky(),
          ),
          // La carte de partage, hors champ le temps de la capture (le
          // RepaintBoundary se photographie très bien en dehors de l'écran).
          if (_carteMontee)
            Positioned(
              left: -1000,
              top: 0,
              child: RepaintBoundary(
                key: _cleCarte,
                child: CartePartageParcours(
                  prenom: ref.read(storageServiceProvider).firstName,
                  parcours: parcours,
                ),
              ),
            ),
          SafeArea(
            child: LayoutBuilder(builder: (context, contraintes) {
              // Départ de la constellation voyageuse : grande, centrée.
              final depart = Rect.fromLTWH(
                AppConstants.spacingLg,
                (contraintes.maxHeight - 300) / 2,
                contraintes.maxWidth - 2 * AppConstants.spacingLg,
                300,
              );
              return Stack(
                key: _cleScene,
                children: [
                  IgnorePointer(
                    ignoring: !pose,
                    child: _contenu(parcours, aujourdHui, montreBilan,
                        faits, pose),
                  ),
                  // La constellation voyageuse : elle se dessine au centre,
                  // puis monte se poser à sa place en haut de la page, et
                  // s'efface en fondu croisé avec la version « état ».
                  // La montée démarre pendant que J7 finit de se poser
                  // (onDone anticipé du reveal), sans temps mort ; 700 ms
                  // pour qu'elle reste ample (550 faisait sec — Paul).
                  if (_overlaySurScene)
                    AnimatedPositioned.fromRect(
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOutCubic,
                      rect: _arrivee == _PhaseArrivee.dessin
                          ? depart
                          : (_rectCible ?? depart),
                      onEnd: _poserConstellation,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: pose ? 0 : 1,
                        child: ConstellationReveal(onDone: _lancerMontee),
                      ),
                    ),
                  // Un tap pendant le dessin saute l'arrivée (pendant la
                  // montée, 700 ms, on laisse finir).
                  if (_arrivee == _PhaseArrivee.dessin)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _passerArrivee,
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _contenu(ParcoursModel parcours, String aujourdHui,
      bool montreBilan, int faits, bool pose) {
    return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Barre haute : retour + menu ──────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingSm),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: AppColors.textPrimary, size: 20),
                      ),
                      const Spacer(),
                      // Partager sa semaine en story : discret, même gamme
                      // que le menu.
                      IconButton(
                        onPressed: _partagerCarte,
                        icon: const Icon(Icons.ios_share,
                            color: AppColors.textMuted, size: 20),
                      ),
                      IconButton(
                        onPressed: _confirmerAbandon,
                        icon: const Icon(Icons.more_horiz,
                            color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spacingLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Hero : la constellation de la semaine ──
                        // (sa clé sert de cible à la constellation
                        // voyageuse de l'arrivée depuis la création)
                        SizedBox(
                          key: _cleHero,
                          height: 110,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: pose ? 1 : 0,
                            child: ConstellationEtat(
                              parcours: parcours,
                              jourNouveau: _jourACelebrer,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingSm),
                        SlideReveal(
                          active: pose,
                          delay: const Duration(milliseconds: 90),
                          child: Text(
                            'TON PROGRAMME AVEC LOUANE',
                            style: AppTextStyles.caption
                                .copyWith(letterSpacing: 1.2),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SlideReveal(
                          active: pose,
                          delay: const Duration(milliseconds: 140),
                          child: Text(
                            parcours.titre,
                            style: AppTextStyles.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // (ni sous-titre ni « Jour X sur 7 » ici : le titre
                        // suffit, le chemin des 7 jours montre où on en est —
                        // demande de Paul.)
                        const SizedBox(height: AppConstants.spacingLg),

                        // ── Le chemin des 7 jours ──────────────
                        for (final (i, jour) in parcours.jours.indexed)
                          SlideReveal(
                            active: pose,
                            delay: Duration(milliseconds: 300 + i * 80),
                            child: _RangJour(
                              parcours: parcours,
                              jour: jour,
                              aujourdHui: aujourdHui,
                              deplie: _deplies.contains(jour.jour),
                              onToggle: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _deplies.contains(jour.jour)
                                      ? _deplies.remove(jour.jour)
                                      : _deplies.add(jour.jour);
                                });
                              },
                            ),
                          ),

                        const SizedBox(height: AppConstants.spacingMd),

                        // ── Les chiffres de la semaine ─────────
                        SlideReveal(
                          active: pose,
                          delay: const Duration(milliseconds: 900),
                          child: _StatsSemaine(parcours: parcours),
                        ),
                        // (la bulle d'encouragement de Louane en bas de
                        // page a été retirée, comme le teaser du bilan :
                        // demande de Paul, la page se termine sur les
                        // chiffres de la semaine.)
                        // ── Le bilan, seulement quand il est là ──
                        // (le teaser « Au bout des 7 jours, on fait le
                        // point » a été retiré : il n'apportait rien.)
                        if (montreBilan) ...[
                          const SizedBox(height: AppConstants.spacingLg),
                          SlideReveal(
                            active: pose,
                            delay: const Duration(milliseconds: 1060),
                            child: _CarteBilan(
                              ressenti: _ressenti,
                              controller: _texteBilan,
                              envoiEnCours: _bilanEnvoye,
                              onRessenti: (r) =>
                                  setState(() => _ressenti = r),
                              onEnvoyer: () => _envoyerBilan(parcours),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppConstants.spacingXl),
                      ],
                    ),
                  ),
                ),
              ],
    );
  }
}

// ── Un jour sur le chemin ────────────────────────────────

enum _EtatJour { fait, courant, futur }

class _RangJour extends ConsumerWidget {
  final ParcoursModel parcours;
  final ParcoursJour jour;
  final String aujourdHui;
  final bool deplie;
  final VoidCallback onToggle;

  const _RangJour({
    required this.parcours,
    required this.jour,
    required this.aujourdHui,
    required this.deplie,
    required this.onToggle,
  });

  _EtatJour get _etat {
    if (parcours.jourTermine(jour.jour)) return _EtatJour.fait;
    if (jour.jour == parcours.jourCourant && !parcours.tousJoursTermines) {
      return _EtatJour.courant;
    }
    return _EtatJour.futur;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final etat = _etat;
    // Un Stack (et pas IntrinsicHeight + Row) : le rail épouse la hauteur
    // réelle du contenu à chaque frame, y compris PENDANT l'animation de
    // dépli/repli d'un jour fait. IntrinsicHeight figeait la hauteur d'un
    // coup pendant qu'AnimatedSize animait encore → débordement.
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 40,
          child: _RailEtoile(
            etat: etat,
            premier: jour.jour == 1,
            dernier: jour.jour == 7,
            cheminFaitAuDessus:
                jour.jour == 1 || parcours.jourTermine(jour.jour - 1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: 40 + AppConstants.spacingSm,
            bottom: AppConstants.spacingMd,
          ),
          child: switch (etat) {
            _EtatJour.fait =>
              _JourFait(jour: jour, deplie: deplie, onToggle: onToggle),
            _EtatJour.courant => _JourCourant(
                parcours: parcours, jour: jour, aujourdHui: aujourdHui),
            _EtatJour.futur => _JourFutur(jour: jour),
          },
        ),
      ],
    );
  }
}

/// Le rail vertical : le trait du chemin + l'étoile du jour. Le trait est
/// turquoise sur la partie déjà parcourue, discret ensuite. L'étoile du jour
/// courant pulse.
class _RailEtoile extends StatefulWidget {
  final _EtatJour etat;
  final bool premier;
  final bool dernier;
  final bool cheminFaitAuDessus;

  const _RailEtoile({
    required this.etat,
    required this.premier,
    required this.dernier,
    required this.cheminFaitAuDessus,
  });

  @override
  State<_RailEtoile> createState() => _RailEtoileState();
}

class _RailEtoileState extends State<_RailEtoile>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.etat == _EtatJour.courant) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RailPainter(
        etat: widget.etat,
        premier: widget.premier,
        dernier: widget.dernier,
        cheminFaitAuDessus: widget.cheminFaitAuDessus,
        pulse: _pulse,
      ),
      size: const Size(40, double.infinity),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.etat,
    required this.premier,
    required this.dernier,
    required this.cheminFaitAuDessus,
    this.pulse,
  }) : super(repaint: pulse);

  final _EtatJour etat;
  final bool premier;
  final bool dernier;
  final bool cheminFaitAuDessus;
  final Animation<double>? pulse;

  static const _x = 20.0;
  static const _yEtoile = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    final allume = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.45)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final eteint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    // Trait au-dessus de l'étoile (vers le jour précédent).
    if (!premier) {
      canvas.drawLine(
        const Offset(_x, 0),
        const Offset(_x, _yEtoile - 11),
        cheminFaitAuDessus ? allume : eteint,
      );
    }
    // Trait en dessous (vers le jour suivant).
    if (!dernier) {
      canvas.drawLine(
        Offset(_x, _yEtoile + 11),
        Offset(_x, size.height),
        etat == _EtatJour.fait ? allume : eteint,
      );
    }

    // L'étoile du jour.
    const pos = Offset(_x, _yEtoile);
    switch (etat) {
      case _EtatJour.fait:
        canvas.drawCircle(
          pos,
          7,
          Paint()
            ..color = AppColors.accent.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawCircle(
            pos, 2.8, Paint()..color = Colors.white.withValues(alpha: 0.95));
      case _EtatJour.courant:
        final p = pulse?.value ?? 0.5;
        canvas.drawCircle(
          pos,
          8 + 4 * p,
          Paint()
            ..color = AppColors.accent.withValues(alpha: 0.25 + 0.30 * p)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(
            pos, 3.2, Paint()..color = Colors.white.withValues(alpha: 0.95));
      case _EtatJour.futur:
        canvas.drawCircle(
            pos, 2.4, Paint()..color = Colors.white.withValues(alpha: 0.20));
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.etat != etat || old.cheminFaitAuDessus != cheminFaitAuDessus;
}

// ── Jour fait : compact, dépliable ───────────────────────

class _JourFait extends StatelessWidget {
  final ParcoursJour jour;
  final bool deplie;
  final VoidCallback onToggle;

  const _JourFait({
    required this.jour,
    required this.deplie,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('JOUR ${jour.jour}',
                      style: AppTextStyles.caption
                          .copyWith(letterSpacing: 0.5)),
                  const SizedBox(width: AppConstants.spacingSm),
                  const Icon(Icons.check_circle,
                      size: 14, color: AppColors.accent),
                  const Spacer(),
                  Icon(
                    deplie ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${jour.titreSeance} · ${jour.dureeMin} min',
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              // Déplié : le mot de Louane + réécouter.
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: deplie
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppConstants.spacingSm),
                          _BulleLouane(texte: jour.motDeLouane),
                          const SizedBox(height: AppConstants.spacingSm),
                          AppButton(
                            label: 'Réécouter',
                            variant: AppButtonVariant.secondary,
                            onTap: () => context.push(
                                AppRoutes.preparationPath(jour.sessionId)),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Jour courant : la grande carte lumineuse ─────────────

class _JourCourant extends ConsumerWidget {
  final ParcoursModel parcours;
  final ParcoursJour jour;
  final String aujourdHui;

  const _JourCourant({
    required this.parcours,
    required this.jour,
    required this.aujourdHui,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final abonne = ref.watch(subscriptionProvider);
    final verrouPremium = jour.premium && !abonne;
    final debloque = parcours.jourDebloque(jour.jour, aujourdHui);
    final session = ref.watch(currentSessionProvider(jour.sessionId));
    final cover = session?.imageFile;

    // Le jour d'aujourd'hui mais la séance d'hier a été faite aujourd'hui :
    // il se dévoilera demain (rythme d'un jour par jour, mystère préservé).
    if (!debloque) {
      return Container(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JOUR ${jour.jour} · DEMAIN',
                      style: AppTextStyles.caption
                          .copyWith(letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Opacity(
                    opacity: 0.6,
                    child: Text(
                      '${jour.titreSeance} · ${jour.dureeMin} min',
                      style: AppTextStyles.bodyLarge
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Se débloque demain',
                      style: AppTextStyles.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      // La bordure est peinte AU-DESSUS du contenu (et pas dans decoration,
      // qui peint dessous) : sinon la cover recouvrait le trait turquoise
      // dans les angles du haut.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // La cover de la séance du jour.
          if (cover != null)
            SizedBox(
              height: 110,
              child: Image.asset(
                'assets/images/$cover',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'JOUR ${jour.jour} · AUJOURD\'HUI',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (verrouPremium)
                      Text('Premium', style: AppTextStyles.badge),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${jour.titreSeance} · ${jour.dureeMin} min',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppConstants.spacingSm),
                _BulleLouane(texte: jour.motDeLouane),
                const SizedBox(height: AppConstants.spacingMd),
                AppButton(
                  label: 'Écouter la séance',
                  onTap: () {
                    if (verrouPremium) {
                      ref.read(vigieProvider).log(
                          'paywall_depuis_parcours', {'jour': jour.jour});
                      context.push(AppRoutes.paywallDepuis('parcours'));
                    } else {
                      context
                          .push(AppRoutes.preparationPath(jour.sessionId));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Jour futur : estompé, mystère partiel ────────────────

class _JourFutur extends StatelessWidget {
  final ParcoursJour jour;

  const _JourFutur({required this.jour});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('JOUR ${jour.jour}',
              style: AppTextStyles.caption.copyWith(letterSpacing: 0.5)),
          const SizedBox(height: 2),
          // Le titre se devine, le mot de Louane se dévoile le jour venu.
          Opacity(
            opacity: 0.45,
            child: Text(
              '${jour.titreSeance} · ${jour.dureeMin} min',
              style: AppTextStyles.bodyLarge
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ── La bulle de Louane (mini avatar + bulle de chat) ─────

class _BulleLouane extends StatelessWidget {
  final String texte;

  const _BulleLouane({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LouaneAvatar(size: 26),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingSm + 2,
            ),
            decoration: const BoxDecoration(
              color: AppColors.accentDim,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Text(
              texte,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary, height: 1.45),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Les chiffres de la semaine ───────────────────────────

class _StatsSemaine extends StatelessWidget {
  final ParcoursModel parcours;

  const _StatsSemaine({required this.parcours});

  @override
  Widget build(BuildContext context) {
    final faits = parcours.joursTermines.length;
    final minutesFaites = parcours.jours
        .where((j) => parcours.jourTermine(j.jour))
        .fold<int>(0, (somme, j) => somme + j.dureeMin);
    final restants = 7 - faits;

    Widget stat(String valeur, String label) => Expanded(
          child: Column(
            children: [
              Text(valeur,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.accent)),
              const SizedBox(height: 2),
              Text(label,
                  style: AppTextStyles.caption, textAlign: TextAlign.center),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.spacingMd,
        horizontal: AppConstants.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: [
          stat('$faits/7', 'séances faites'),
          Container(width: 1, height: 28, color: AppColors.accentDim),
          stat('$minutesFaites min', 'de calme pris'),
          Container(width: 1, height: 28, color: AppColors.accentDim),
          stat(
            restants == 0 ? 'Bilan' : '$restants',
            restants == 0
                ? 'à faire ensemble'
                : restants == 1
                    ? 'jour restant'
                    : 'jours restants',
          ),
        ],
      ),
    );
  }
}

// ── Le bilan de fin de semaine ───────────────────────────

class _CarteBilan extends StatelessWidget {
  final String? ressenti;
  final TextEditingController controller;
  final bool envoiEnCours;
  final ValueChanged<String> onRessenti;
  final VoidCallback onEnvoyer;

  const _CarteBilan({
    required this.ressenti,
    required this.controller,
    required this.envoiEnCours,
    required this.onRessenti,
    required this.onEnvoyer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.accent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.18),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alors, cette semaine ?', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Dis-moi comment tu te sens, Louane t\'attend pour en parler.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Wrap(
            spacing: AppConstants.spacingSm,
            runSpacing: AppConstants.spacingSm,
            children: [
              for (final r in kRessentisBilan)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onRessenti(r);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: AppConstants.spacingSm,
                    ),
                    decoration: BoxDecoration(
                      color: r == ressenti
                          ? AppColors.accentDim
                          : AppColors.background,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusXl),
                      border: Border.all(
                        color: r == ressenti
                            ? AppColors.accent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      r,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: r == ressenti
                            ? AppColors.accent
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingMd),
          TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Un mot de plus, si tu veux',
              hintStyle: AppTextStyles.bodyMedium,
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          AppButton(
            label: 'Envoyer à Louane',
            isLoading: envoiEnCours,
            onTap: ressenti == null ? null : onEnvoyer,
          ),
        ],
      ),
    );
  }
}
