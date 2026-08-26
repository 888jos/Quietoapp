import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/parcours_model.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/starry_background.dart';
import '../../explore/explore_providers.dart';
import '../../home/presentation/widgets/night_sky_header.dart';
import '../../louane/louane_providers.dart';
import '../../louane/presentation/widgets/louane_avatar.dart';
import '../data/parcours_repository.dart';
import '../parcours_providers.dart';

/// Les étapes que Louane coche pendant qu'elle compose. Les trois premières
/// se valident en rythme (avec une petite vibration à chaque coche) ; la
/// dernière attend la VRAIE réponse du serveur. Textes en dur : majuscule
/// initiale, pas d'emoji, pas de tiret long. Public pour le test de style.
const List<String> kEtapesCreationParcours = [
  "J'écoute ce que tu m'as raconté",
  'Je choisis tes séances, une par jour',
  "Je t'écris un petit mot pour chaque jour",
  'Je finalise ton programme',
];

enum _Phase { attente, echec }

/// Le moment « wow », première partie : Louane compose le programme sous les
/// yeux de la personne (avatar + anneau + pourcentage + checklist). Quand le
/// programme est prêt, on bascule sur la page du programme, où la
/// constellation se dessine puis monte se poser en haut : la révélation se
/// joue là-bas, dans le vrai décor.
class ParcoursCreationPage extends ConsumerStatefulWidget {
  const ParcoursCreationPage({super.key, this.demo = false});

  /// PROVISOIRE (dev, bouton du profil) : déroule l'animation complète avec
  /// un programme fictif construit depuis le catalogue local. Zéro appel
  /// serveur, zéro coût IA, aucun événement Vigie. Le programme fictif est
  /// installé comme un vrai (il remplace l'actuel) pour voir aussi la
  /// révélation et la page du programme. Toujours false en release (routeur).
  final bool demo;

  @override
  ConsumerState<ParcoursCreationPage> createState() =>
      _ParcoursCreationPageState();
}

class _ParcoursCreationPageState extends ConsumerState<ParcoursCreationPage> {
  _Phase _phase = _Phase.attente;

  /// Progression affichée (0..1) : avance douce sur ~10 s qui ralentit en
  /// approchant de ~95 %, et ne passe à 100 % qu'avec la vraie réponse.
  double _progression = 0;

  /// Nombre d'étapes cochées (0..4), dérivé de la progression (25 % chacune).
  /// La 4e attend la réponse du serveur.
  int _etapesFaites = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Garde anti-double génération : un programme existe déjà → on va le
    // voir. En démo on passe outre (rejouable à volonté) et on ne trace
    // rien : la Vigie ne doit voir que les vraies créations.
    if (!widget.demo && ref.read(parcoursProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement(AppRoutes.parcours);
      });
      return;
    }
    if (!widget.demo) ref.read(vigieProvider).log('parcours_creation_vue');
    _lancer();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Fait grimper la progression sur ~10 s : une avance douce et régulière
  /// qui ralentit progressivement (ease-out calé sur le temps réel, pas de
  /// bond à 30 % dès la première seconde), jusqu'à ~95 %. Les étapes se
  /// cochent aux paliers de 25 %, chacune avec une petite vibration : c'est
  /// le côté « elle travaille vraiment » qui rend l'attente satisfaisante.
  /// Le 100 % et la 4e coche n'arrivent qu'avec la vraie réponse.
  static const _dureeProgression = Duration(seconds: 10);

  void _demarrerProgression() {
    _ticker?.cancel();
    final chrono = Stopwatch()..start();
    setState(() {
      _progression = 0;
      _etapesFaites = 0;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      final t = chrono.elapsedMilliseconds / _dureeProgression.inMilliseconds;
      setState(() {
        if (t < 1.0) {
          _progression = 0.95 * (1 - math.pow(1 - t, 1.8).toDouble());
        } else {
          // Le serveur dépasse les 10 s : on ne fige JAMAIS l'anneau. Avance
          // à peine perceptible vers 99 % (~96 % à +7 s, ~97 % à +15 s) ;
          // le 100 % reste gagné par la vraie réponse.
          _progression += (0.99 - _progression) * 0.004;
        }
        final paliers = _progression >= 0.75
            ? 3
            : _progression >= 0.50
                ? 2
                : _progression >= 0.25
                    ? 1
                    : 0;
        if (paliers > _etapesFaites) {
          _etapesFaites = paliers;
          HapticFeedback.lightImpact();
        }
      });
    });
  }

  Future<void> _lancer() async {
    setState(() => _phase = _Phase.attente);
    _demarrerProgression();
    try {
      final Future<ParcoursGenere> generation;
      if (widget.demo) {
        generation = _genererDemo();
      } else {
        // Cache santé normalement déjà chaud (page Louane) ; borné à 2 s pour
        // ne jamais retarder la création du programme.
        await HealthService.instance
            .resumeSanteMentale()
            .timeout(const Duration(seconds: 2), onTimeout: () => '');
        final historique =
            ref.read(louaneChatProvider.notifier).historiquePourParcours();
        generation = ref.read(parcoursRepositoryProvider).generer(historique);
      }
      // L'attente est un moment (filmable) : 6 s minimum, même si le serveur
      // répond avant. S'il est plus lent, la dernière étape reste en cours.
      final resultats = await Future.wait<Object?>([
        generation,
        Future.delayed(const Duration(seconds: 6)),
      ]);
      if (!mounted) return;
      final genere = resultats.first as ParcoursGenere;

      // Persisté AVANT l'animation : quitter maintenant ne perd rien.
      await ref
          .read(parcoursProvider.notifier)
          .enregistrer(genere.parcours, marquerCree: !widget.demo);
      // La bulle d'ouverture de Louane rejoint le fil de conversation
      // (en remplaçant celle d'un éventuel programme précédent annulé).
      if (genere.messageOuverture.isNotEmpty) {
        ref
            .read(louaneChatProvider.notifier)
            .ajouterBulleOuvertureParcours(genere.messageOuverture);
      }
      if (!mounted) return;
      // Le programme en main : l'anneau file à 100 %, la dernière coche
      // tombe avec une vibration plus marquée, un temps pour la savourer,
      // puis la constellation.
      _ticker?.cancel();
      for (var i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 40));
        if (!mounted) return;
        setState(
            () => _progression = _progression + (1.0 - _progression) * 0.45);
      }
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _progression = 1.0;
        _etapesFaites = 4;
      });
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      // La révélation se joue sur la page du programme : la constellation
      // s'y dessine, monte se poser en haut, et le contenu suit.
      context.pushReplacement('${AppRoutes.parcours}?creation=1');
    } catch (e) {
      debugPrint('[Parcours] génération échouée : $e');
      if (!widget.demo) {
        ref.read(vigieProvider).log('parcours_generation_echec');
      }
      if (!mounted) return;
      _ticker?.cancel();
      setState(() => _phase = _Phase.echec);
    }
  }

  /// PROVISOIRE (dev) : le faux serveur. Attend ~9 s (le temps que l'anneau
  /// déroule toute sa montée) puis fabrique un programme crédible depuis le
  /// catalogue local : une séance par catégorie pour la variété, complété
  /// dans l'ordre du catalogue. Pas de bulle d'ouverture (messageOuverture
  /// vide) : le fil de conversation de Louane reste propre.
  Future<ParcoursGenere> _genererDemo() async {
    await Future.delayed(const Duration(seconds: 9));
    final categories = ref.read(exploreRepositoryProvider).fetchCategories();
    final choisies = <SessionModel>[
      for (final c in categories)
        if (c.sessions.isNotEmpty) c.sessions.first,
    ];
    for (final s in categories.expand((c) => c.sessions)) {
      if (choisies.length >= 7) break;
      if (!choisies.contains(s)) choisies.add(s);
    }
    const mots = [
      'On commence tout doux. Juste toi et ta respiration.',
      "Aujourd'hui, on relâche les épaules. Tu me diras.",
      'Une petite pause au milieu de ta semaine.',
      "Tu avances bien. Celle-ci, c'est ma préférée.",
      'On ralentit encore un peu. Prends ton temps.',
      'Avant-dernier jour. Tu connais le chemin maintenant.',
      "Dernier jour. Je suis fière du chemin qu'on a fait.",
    ];
    return ParcoursGenere(
      parcours: ParcoursModel(
        titre: 'Une semaine pour souffler',
        sousTitre: 'Sept jours avec Louane, à ton rythme',
        jours: [
          for (var i = 0; i < 7 && i < choisies.length; i++)
            ParcoursJour(
              jour: i + 1,
              sessionId: choisies[i].id,
              titreSeance: choisies[i].title,
              dureeMin: choisies[i].durationMinutes,
              premium: choisies[i].isPremium,
              motDeLouane: mots[i],
            ),
        ],
        creeLe: DateTime.now().toIso8601String(),
      ),
      messageOuverture: '',
      fallback: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 330,
            child: AuroraSky(),
          ),
          SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: switch (_phase) {
                _Phase.attente => _VueAttente(
                    key: const ValueKey('attente'),
                    progression: _progression,
                    etapesFaites: _etapesFaites,
                  ),
                _Phase.echec => _VueEchec(
                    key: const ValueKey('echec'),
                    onRetry: _lancer,
                  ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phase 1 : l'attente (Louane au centre, anneau de progression,
// pourcentage, checklist) ──

class _VueAttente extends StatelessWidget {
  final double progression;
  final int etapesFaites;

  const _VueAttente({
    super.key,
    required this.progression,
    required this.etapesFaites,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
      child: Column(
        children: [
          const Spacer(flex: 2),
          // Le cœur : Louane au centre (elle travaille, elle s'illumine),
          // l'anneau de points qui s'allument autour d'elle, le halo qui
          // respire derrière.
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(child: _HaloRespirant()),
                CustomPaint(
                  painter: _AnneauProgresPainter(progression),
                  size: const Size(172, 172),
                ),
                const LouaneAvatar(size: 84, parle: true),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingSm),
          // Le pourcentage qui grimpe, gros et fier : il ne touche 100 %
          // qu'avec le programme vraiment prêt en main.
          Text(
            '${(progression * 100).round()} %',
            style: AppTextStyles.displayLarge.copyWith(
              color: AppColors.accent,
              fontSize: 36,
            ),
          ),
          const Spacer(flex: 1),
          _ChecklistCreation(etapesFaites: etapesFaites),
          const SizedBox(height: AppConstants.spacingMd),
          const SizedBox(height: 50, child: StardustTrail()),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

/// L'anneau de progression : 36 points autour de Louane, qui s'allument en
/// turquoise au fil de l'avancée (le dernier allumé brille plus fort, c'est
/// la tête qui avance). Les points encore éteints attendent, discrets. Même
/// langage de points lumineux que le ciel étoilé.
class _AnneauProgresPainter extends CustomPainter {
  _AnneauProgresPainter(this.progression);

  final double progression;

  static const _nbPoints = 36;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final rayon = size.width / 2 - 8;
    final nbAllumes = (progression * _nbPoints).floor().clamp(0, _nbPoints);
    final paint = Paint();

    for (var i = 0; i < _nbPoints; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / _nbPoints;
      final pos = centre +
          Offset(math.cos(angle) * rayon, math.sin(angle) * rayon);
      final allume = i < nbAllumes;
      final tete = allume && i == nbAllumes - 1;

      if (allume) {
        // Halo doux sous chaque point allumé, plus marqué sur la tête.
        canvas.drawCircle(
          pos,
          tete ? 5.5 : 3.6,
          Paint()
            ..color = AppColors.accent.withValues(alpha: tete ? 0.55 : 0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        paint.color = tete ? Colors.white : AppColors.accent;
        canvas.drawCircle(pos, tete ? 2.8 : 2.2, paint);
      } else {
        paint.color = Colors.white.withValues(alpha: 0.14);
        canvas.drawCircle(pos, 2.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AnneauProgresPainter old) =>
      old.progression != progression;
}

/// La checklist de création : chaque étape passe de « à venir » à « en
/// cours » (petit anneau qui tourne) puis « cochée » (coche turquoise qui
/// pope). Les vibrations partent du parent, au moment où l'étape se coche.
class _ChecklistCreation extends StatelessWidget {
  final int etapesFaites;

  const _ChecklistCreation({required this.etapesFaites});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, etape) in kEtapesCreationParcours.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: i < etapesFaites
                        ? const _CocheEtape()
                        : i == etapesFaites
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: AppColors.accent,
                                ),
                              )
                            : Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.textMuted,
                                    width: 1.2,
                                  ),
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: i <= etapesFaites
                          ? AppColors.textPrimary
                          : AppColors.textMuted.withValues(alpha: 0.45),
                    ),
                    child: Text(etape),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La coche qui « pope » : elle arrive avec un petit rebond, en même temps
/// que la vibration → c'est ça, le geste satisfaisant.
class _CocheEtape extends StatefulWidget {
  const _CocheEtape();

  @override
  State<_CocheEtape> createState() => _CocheEtapeState();
}

class _CocheEtapeState extends State<_CocheEtape>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
      child: Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, size: 13, color: AppColors.background),
      ),
    );
  }
}

/// Le halo central qui respire pendant que Louane compose : des cercles
/// concentriques flous au rythme d'une respiration lente (période 4 s),
/// même douceur que la lune de l'accueil.
class _HaloRespirant extends StatefulWidget {
  const _HaloRespirant();

  @override
  State<_HaloRespirant> createState() => _HaloRespirantState();
}

class _HaloRespirantState extends State<_HaloRespirant>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(painter: _HaloPainter(_c), size: Size.infinite),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    // 0..1..0 en douceur : l'inspiration et l'expiration.
    final souffle = 0.5 + 0.5 * math.sin(2 * math.pi * anim.value - math.pi / 2);
    final k = 0.85 + 0.15 * souffle;

    void halo(double rayon, double alpha, double flou) {
      canvas.drawCircle(
        centre,
        rayon * k,
        Paint()
          ..color = AppColors.accent.withValues(alpha: alpha * (0.7 + 0.3 * souffle))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, flou),
      );
    }

    halo(84, 0.05, 30);
    halo(58, 0.10, 22);
    halo(34, 0.16, 14);
    // Le cœur, petite étoile blanche qui veille.
    canvas.drawCircle(
      centre,
      3.0,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55 + 0.35 * souffle)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(_HaloPainter old) => false;
}

// ── Échec : message doux + réessayer ──

class _VueEchec extends StatelessWidget {
  final VoidCallback onRetry;

  const _VueEchec({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Je n'arrive pas à terminer ton programme là, tout de suite. "
            'On réessaie ?',
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          AppButton(label: 'Réessayer', onTap: onRetry),
          const SizedBox(height: AppConstants.spacingSm),
          AppButton(
            label: 'Plus tard',
            variant: AppButtonVariant.ghost,
            onTap: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
