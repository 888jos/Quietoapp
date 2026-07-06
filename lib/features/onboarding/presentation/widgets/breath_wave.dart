import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Exercice de respiration guidé en 3 temps :
///  1. Intro : « Prêt ? » puis 3, 2, 1. Le parcours est déjà
///     visible : la première colline glisse vers la bulle à la vitesse de
///     l'exercice et l'atteint pile à la fin du décompte — on voit venir
///     le moment où il faudra inspirer.
///  2. Exercice : le parcours compte EXACTEMENT une colline par
///     respiration. Montée = inspire, descente = expire (plus longue,
///     c'est elle qui détend). Anneaux repères au sommet et au creux,
///     vibration à chaque bascule. Après la dernière colline, la ligne
///     devient plate jusqu'à un point d'arrivée : on voit la fin approcher.
///  3. Fin : « Bien joué ✨ », la mer finit de s'aplatir.
class BreathWave extends StatefulWidget {
  /// Nombre de respirations complètes.
  final int cycles;

  /// Durée de l'inspiration (bulle qui monte).
  final Duration inhale;

  /// Durée de l'expiration (bulle qui descend).
  final Duration exhale;

  const BreathWave({
    super.key,
    this.cycles = 3,
    this.inhale = const Duration(seconds: 4),
    this.exhale = const Duration(seconds: 6),
  });

  @override
  State<BreathWave> createState() => _BreathWaveState();
}

enum _Phase { intro, running, done }

class _BreathWaveState extends State<BreathWave> with TickerProviderStateMixin {
  late final AnimationController _controller;

  /// Fait glisser le parcours vers la bulle pendant le décompte, à la
  /// même vitesse que l'exercice : aucun à-coup au démarrage.
  late final AnimationController _approach;

  /// Hauteur de la mer : 1 = vague pleine, 0 = ligne calme (fin).
  late final AnimationController _amp;
  late final CurvedAnimation _ampCurved;

  _Phase _phase = _Phase.intro;
  String _introLabel = 'Prêt ?';
  final List<Timer> _timers = [];

  double _prevCycleProgress = 0;
  bool _peakFired = false;

  /// Valeurs du contrôleur au dernier sommet / creux, pour animer les
  /// anneaux qui pulsent ~600 ms après chaque bascule.
  double? _peakAt;
  double? _troughAt;

  /// Durée du décompte d'intro (« Respirons ensemble », 3, 2, 1).
  static const int _introMs = 4300;

  Duration get _cycle => widget.inhale + widget.exhale;

  /// Part de l'inspiration dans un cycle (position du sommet).
  double get _peakShare => widget.inhale.inMilliseconds / _cycle.inMilliseconds;

  /// Distance parcourue pendant l'intro, en cycles.
  double get _preRoll => _introMs / _cycle.inMilliseconds;

  /// Position de la bulle le long du parcours, en cycles :
  /// négative pendant l'intro (la première colline approche),
  /// 0 → cycles pendant l'exercice, cycles à la fin.
  double get _sBall => switch (_phase) {
    _Phase.intro => -_preRoll * (1 - _approach.value),
    _ => _controller.value * widget.cycles,
  };

  /// Progression 0 → 1 dans le cycle en cours.
  double get _cycleProgress =>
      _phase == _Phase.done ? 1 : (_controller.value * widget.cycles) % 1.0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: _cycle * widget.cycles)
          ..addListener(_onTick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              // Fin de la dernière expiration : la mer se calme.
              setState(() => _phase = _Phase.done);
              _amp.reverse();
            }
          });
    _approach =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: _introMs),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              // La colline atteint la bulle : l'exercice démarre.
              HapticFeedback.lightImpact();
              setState(() => _phase = _Phase.running);
              _controller.forward();
            }
          })
          ..forward();
    _amp = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 1400),
      // La vague est pleine dès l'intro : on voit le parcours arriver.
      value: 1.0,
    );
    _ampCurved = CurvedAnimation(
      parent: _amp,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _runIntro();
  }

  /// « Prêt ? » → 3 → 2 → 1 (le départ est déclenché par
  /// [_approach] pour coller exactement à l'arrivée de la colline).
  void _runIntro() {
    void at(int ms, VoidCallback action) {
      _timers.add(
        Timer(Duration(milliseconds: ms), () {
          if (mounted) action();
        }),
      );
    }

    at(1600, () {
      HapticFeedback.selectionClick();
      setState(() => _introLabel = '3');
    });
    at(2500, () {
      HapticFeedback.selectionClick();
      setState(() => _introLabel = '2');
    });
    at(3400, () {
      HapticFeedback.selectionClick();
      setState(() => _introLabel = '1');
    });
  }

  /// Vibrations : moyenne au sommet (bascule vers l'expiration),
  /// douce au creux (nouvelle inspiration, ou toute fin).
  void _onTick() {
    if (_phase != _Phase.running) return;
    final p = _cycleProgress;
    if (!_peakFired && p >= _peakShare) {
      _peakFired = true;
      _peakAt = _controller.value;
      HapticFeedback.mediumImpact();
    }
    if (p < _prevCycleProgress) {
      // La vague a bouclé : début d'un nouveau cycle (ou fin).
      _peakFired = false;
      _troughAt = _controller.value;
      HapticFeedback.lightImpact();
    }
    _prevCycleProgress = p;
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _ampCurved.dispose();
    _controller.dispose();
    _approach.dispose();
    _amp.dispose();
    super.dispose();
  }

  /// Progression 0 → 1 d'un anneau qui pulse, à partir de la valeur du
  /// contrôleur au moment de la bascule. 1 = pulse terminé (invisible).
  double _pulseFrom(double? at) {
    if (at == null || _phase == _Phase.done) return 1.0;
    final totalMs = _controller.duration!.inMilliseconds;
    return (((_controller.value - at) * totalMs) / 600).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _approach, _amp]),
      builder: (context, _) {
        final p = _cycleProgress;
        final inhaling = p < _peakShare;

        // Secondes restantes dans la phase en cours.
        final cycleSeconds = _cycle.inMilliseconds / 1000;
        final secondsLeft = inhaling
            ? ((_peakShare - p) * cycleSeconds).ceil()
            : ((1 - p) * cycleSeconds).ceil();

        final label = switch (_phase) {
          _Phase.intro => _introLabel,
          _Phase.done => 'Bien joué ✨',
          _Phase.running => inhaling ? 'Inspire' : 'Expire',
        };

        final cycleIndex =
            (_controller.value * widget.cycles).floor().clamp(
              0,
              widget.cycles - 1,
            ) +
            1;

        // Le décompte 3, 2, 1 s'affiche en très grand : c'est le moment
        // clé qui prépare la personne, il doit dominer l'écran.
        final isCountdown =
            _phase == _Phase.intro && int.tryParse(_introLabel) != null;

        return Column(
          children: [
            SizedBox(
              height: 76,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: isCountdown
                        ? AppTextStyles.displayLarge.copyWith(
                            fontSize: 56,
                            color: AppColors.accent,
                          )
                        : AppTextStyles.titleLarge.copyWith(
                            fontSize: 26,
                            color: _phase == _Phase.done
                                ? AppColors.textPrimary
                                : AppColors.accent,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 20,
              child: Text(
                _phase == _Phase.running ? '$secondsLeft' : '',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
            RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 190),
                painter: _WavePainter(
                  sBall: _sBall,
                  cycles: widget.cycles,
                  peakShare: _peakShare,
                  amplitudeFactor: _ampCurved.value,
                  peakPulse: _pulseFrom(_peakAt),
                  troughPulse: _pulseFrom(_troughAt),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 3 barres qui se remplissent au fil des respirations : on voit
            // d'un coup d'œil combien il y en a et où on en est.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.cycles; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: 30,
                    height: 6,
                    margin: EdgeInsets.only(
                      right: i < widget.cycles - 1 ? 8 : 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color:
                          _phase == _Phase.done ||
                              (_phase == _Phase.running && i < cycleIndex)
                          ? AppColors.accent
                          : AppColors.accentDim,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 22,
              child: Text(
                switch (_phase) {
                  _Phase.intro => '${widget.cycles} respirations',
                  _Phase.running =>
                    'Respiration $cycleIndex sur ${widget.cycles}',
                  _Phase.done => '${widget.cycles} sur ${widget.cycles}',
                },
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dessine la mer : un parcours FINI (une colline par respiration, plat
/// avant et après), la bulle qui le suit, les anneaux repères au sommet
/// et au creux de chaque colline, le point d'arrivée, et les pulses de
/// bascule.
class _WavePainter extends CustomPainter {
  /// Position de la bulle le long du parcours, en cycles
  /// (négative pendant l'intro, [cycles] à la fin).
  final double sBall;
  final int cycles;
  final double peakShare;

  /// 0 = mer plate (fin), 1 = vague pleine.
  final double amplitudeFactor;
  final double peakPulse;
  final double troughPulse;

  _WavePainter({
    required this.sBall,
    required this.cycles,
    required this.peakShare,
    required this.amplitudeFactor,
    required this.peakPulse,
    required this.troughPulse,
  });

  /// Hauteur du parcours (0 = creux, 1 = sommet) pour une position s en
  /// cycles. Plat avant la première colline et après la dernière : le
  /// parcours a un début et une fin visibles. Montée puis descente en
  /// cosinus : départs et arrivées parfaitement doux.
  double _hill(double s) {
    if (s <= 0 || s >= cycles) return 0;
    final f = s % 1.0;
    if (f < peakShare) {
      return 0.5 * (1 - math.cos(math.pi * f / peakShare));
    }
    return 0.5 * (1 + math.cos(math.pi * (f - peakShare) / (1 - peakShare)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final baseline = h * 0.86;
    final amplitude = h * 0.62 * amplitudeFactor;
    final wavelength = w * 0.8;

    // Position dans le parcours d'un x à l'écran : la bulle est fixe au
    // centre, c'est le parcours qui défile sous elle.
    double sAt(double x) => (x - w / 2) / wavelength + sBall;
    double yAt(double x) => baseline - amplitude * _hill(sAt(x));

    // ── La vague ──────────────────────────────────────
    final path = Path()..moveTo(0, yAt(0));
    for (double x = 3; x <= w; x += 3) {
      path.lineTo(x, yAt(x));
    }

    // Remplissage doux sous la vague.
    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.accent.withValues(alpha: 0.14),
                AppColors.accent.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromLTWH(
                0,
                baseline - amplitude,
                w,
                amplitude + (h - baseline),
              ),
            ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // ── Les anneaux repères ───────────────────────────
    // Un au sommet de chaque colline (bascule expire), un au creux entre
    // les collines, et un point d'arrivée PLEIN à la toute fin.
    final markerPaint = Paint()
      ..color = AppColors.textMuted.withValues(alpha: 0.7 * amplitudeFactor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final peakY = baseline - amplitude;
    for (var k = 0; k < cycles; k++) {
      final peakX = w / 2 + wavelength * (k + peakShare - sBall);
      if (peakX >= -10 && peakX <= w + 10) {
        canvas.drawCircle(Offset(peakX, peakY), 4, markerPaint);
      }
    }
    for (var k = 0; k <= cycles; k++) {
      final troughX = w / 2 + wavelength * (k - sBall);
      if (troughX < -10 || troughX > w + 10) continue;
      if (k == cycles) {
        // Le point d'arrivée : plein, pour marquer la fin du parcours.
        canvas.drawCircle(
          Offset(troughX, baseline),
          4.5,
          Paint()
            ..color = AppColors.accent.withValues(
              alpha: 0.9 * amplitudeFactor,
            ),
        );
      } else {
        canvas.drawCircle(Offset(troughX, baseline), 4, markerPaint);
      }
    }

    // ── Pulses de bascule (anneau qui s'élargit) ──────
    void pulseRing(double pulse, Offset center) {
      if (pulse >= 1.0) return;
      canvas.drawCircle(
        center,
        10 + 26 * pulse,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.55 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    pulseRing(peakPulse, Offset(w / 2, peakY));
    pulseRing(troughPulse, Offset(w / 2, baseline));

    // ── La bulle ──────────────────────────────────────
    final ball = Offset(w / 2, baseline - amplitude * _hill(sBall));
    canvas.drawCircle(
      ball,
      18,
      Paint()
        ..color = AppColors.accent.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawCircle(ball, 9, Paint()..color = AppColors.accent);
    canvas.drawCircle(
      ball,
      3.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.sBall != sBall ||
      old.amplitudeFactor != amplitudeFactor ||
      old.peakPulse != peakPulse ||
      old.troughPulse != troughPulse;
}
