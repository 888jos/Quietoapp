import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/services/health_service.dart';
import '../../../core/services/storage_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/ui/app_button.dart';
import '../../../core/ui/starry_background.dart';
import 'widgets/slide_reveal.dart';

/// Connexion à Apple Santé (iOS uniquement, juste après « Voici ton
/// programme ») : on propose d'ajouter automatiquement les minutes d'écoute
/// dans Santé > Pleine conscience. « Plus tard » ne ferme pas la porte :
/// la demande système reviendra au premier play (filet dans le handler audio).
class OnboardingHealthPage extends ConsumerStatefulWidget {
  const OnboardingHealthPage({super.key});

  @override
  ConsumerState<OnboardingHealthPage> createState() =>
      _OnboardingHealthPageState();
}

class _OnboardingHealthPageState extends ConsumerState<OnboardingHealthPage> {
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    ref.read(vigieProvider).log('onboarding_etape', {'etape': 'sante'});
  }

  Future<void> _connect() async {
    if (_connecting) return;
    setState(() => _connecting = true);
    ref.read(vigieProvider).log('onboarding_sante', {'choix': 'connecter'});
    // Affiche la feuille d'autorisation iOS et attend la réponse. Quoi que
    // choisisse l'utilisateur, on continue le flux sans bloquer.
    await HealthService.instance.requestAuthorization();
    await ref.read(storageServiceProvider).setHealthPromptSeen();
    if (!mounted) return;
    context.go(AppRoutes.onboardingBreath);
  }

  void _skip() {
    ref.read(vigieProvider).log('onboarding_sante', {'choix': 'plus_tard'});
    context.go(AppRoutes.onboardingBreath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingLg,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Column(
                      // En haut de page (pas centré verticalement) : le schéma
                      // accueille tout de suite, l'espace libre reste en bas.
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Le vide de la page est réparti : 2 parts au-dessus
                        // du schéma, 3 parts sous l'encadré. Le bloc descend
                        // un peu et le trou du bas se réduit d'autant.
                        const Spacer(flex: 2),
                        const SlideReveal(
                          active: true,
                          child: Center(child: _ConnectionVisual()),
                        ),
                        const SizedBox(height: AppConstants.spacingXl),
                        SlideReveal(
                          active: true,
                          delay: const Duration(milliseconds: 130),
                          child: Text(
                            'Suis ton évolution',
                            style: AppTextStyles.displayLarge,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingLg),
                        SlideReveal(
                          active: true,
                          delay: const Duration(milliseconds: 240),
                          child: Container(
                            padding:
                                const EdgeInsets.all(AppConstants.spacingMd),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusLg,
                              ),
                              border: Border.all(
                                color:
                                    AppColors.accent.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'Quand tu écoutes une séance, tes minutes de '
                              'calme sont ajoutées dans l\'app Santé. Tu vois '
                              'tes progrès jour après jour. Et si tu remplis '
                              'les questionnaires de bien-être de Santé, '
                              'Louane pourra en tenir compte.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spacingLg),
                        SlideReveal(
                          active: true,
                          delay: const Duration(milliseconds: 350),
                          child: const Text(
                            'Tout reste sur ton iPhone. '
                            'Tu peux couper ça quand tu veux.',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // L'espace restant de la page se place ici, entre le
                        // bloc de contenu et les boutons.
                        const Spacer(flex: 3),
                      ],
                    ),
                  ),
                  SlideReveal(
                    active: true,
                    delay: const Duration(milliseconds: 470),
                    child: AppButton(
                      label: 'Connecter à Apple Santé',
                      isLoading: _connecting,
                      onTap: _connect,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skip,
                    child: const Padding(
                      padding: EdgeInsets.all(AppConstants.spacingSm),
                      child: Text(
                        'Plus tard',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingSm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Icône façon app Santé d'Apple, redessinée : carré blanc arrondi, cœur en
/// dégradé rose. Reconnaissable au premier coup d'œil, sans embarquer
/// l'artwork d'Apple.
class _AppleHealthIcon extends StatelessWidget {
  final double size;

  const _AppleHealthIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        // Courbure des icônes iOS (~22,5 % du côté).
        borderRadius: BorderRadius.circular(size * 0.225),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.045),
          ),
        ],
      ),
      // Taille explicite : sans elle, le CustomPaint se replie à 0 pixel
      // et le cœur n'apparaît pas.
      child: CustomPaint(
        size: Size.square(size),
        painter: const _HealthHeartPainter(),
      ),
    );
  }
}

/// Le cœur exact de l'icône Santé, mesuré pixel par pixel sur l'icône
/// officielle d'Apple : il occupe le haut droit du carré blanc (boîte
/// x 0,378-0,845 / y 0,166-0,572 du carré) avec un dégradé vertical du rose
/// #FF66B2 au rouge #FF2719 et un creux central peu profond.
class _HealthHeartPainter extends CustomPainter {
  const _HealthHeartPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTRB(
      size.width * 0.378,
      size.height * 0.166,
      size.width * 0.845,
      size.height * 0.572,
    );
    Offset o(double x, double y) =>
        Offset(r.left + x * r.width, r.top + y * r.height);
    void curve(Path p, Offset c1, Offset c2, Offset end) =>
        p.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    final heart = Path()..moveTo(o(0.5, 0.10).dx, o(0.5, 0.10).dy);
    curve(heart, o(0.40, -0.02), o(0.22, -0.02), o(0.125, 0.06));
    curve(heart, o(0.02, 0.15), o(0.0, 0.30), o(0.03, 0.42));
    curve(heart, o(0.06, 0.62), o(0.22, 0.82), o(0.5, 1.0));
    curve(heart, o(0.78, 0.82), o(0.94, 0.62), o(0.97, 0.42));
    curve(heart, o(1.0, 0.30), o(0.98, 0.15), o(0.875, 0.06));
    curve(heart, o(0.78, -0.02), o(0.60, -0.02), o(0.5, 0.10));
    heart.close();

    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF66B2), Color(0xFFFF2719)],
      ).createShader(r);
    canvas.drawPath(heart, paint);
  }

  @override
  bool shouldRepaint(_HealthHeartPainter oldDelegate) => false;
}

/// Le schéma de connexion : Quieto en haut à gauche, Apple Santé en bas à
/// droite, reliés par une flèche ondulée en pointillés qui se dessine
/// doucement et vient pointer l'icône Santé.
class _ConnectionVisual extends StatefulWidget {
  const _ConnectionVisual();

  @override
  State<_ConnectionVisual> createState() => _ConnectionVisualState();
}

class _ConnectionVisualState extends State<_ConnectionVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _trace;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _trace = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    // La flèche se dessine une fois la page posée.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Apple Santé plus gros que Quieto (c'est lui la destination, le point
    // important) et un peu rentré vers le centre.
    return SizedBox(
      width: 260,
      height: 180,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _trace,
              builder: (context, _) =>
                  CustomPaint(painter: _ArrowPainter(_trace.value)),
            ),
          ),
          const Positioned(left: 0, top: 0, child: _QuietoIcon(size: 64)),
          const Positioned(
            right: 24,
            bottom: 0,
            child: _AppleHealthIcon(size: 96),
          ),
        ],
      ),
    );
  }
}

/// La flèche ondulée, dessinée en pointillés au fil de [progress] (0 → 1),
/// avec la tête de flèche qui avance au bout du trait.
class _ArrowPainter extends CustomPainter {
  final double progress;

  const _ArrowPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final paint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Part de sous Quieto, fait une vague, et vient pointer l'icône Santé
    // (le trait s'arrête juste avant son bord, la pointe orientée vers elle).
    final path = Path()
      ..moveTo(size.width * 0.138, size.height * 0.43)
      ..cubicTo(
        size.width * 0.10, size.height * 0.82,
        size.width * 0.36, size.height * 0.32,
        size.width * 0.508, size.height * 0.56,
      );

    final metric = path.computeMetrics().first;
    final drawn = metric.length * progress;

    // Trait en pointillés, dévoilé progressivement.
    const dash = 7.0;
    const gap = 6.0;
    var d = 0.0;
    while (d < drawn) {
      final end = math.min(d + dash, drawn);
      canvas.drawPath(metric.extractPath(d, end), paint);
      d += dash + gap;
    }

    // Tête de flèche au bout du trait, orientée selon la tangente.
    final tip = metric.getTangentForOffset(drawn);
    if (tip == null) return;
    final dir = tip.vector.direction;
    const headLen = 9.0;
    const spread = 2.7; // ouverture des deux branches (~155 degrés)
    final p = tip.position;
    canvas.drawLine(
      p,
      p + Offset(math.cos(dir + spread), math.sin(dir + spread)) * headLen,
      paint,
    );
    canvas.drawLine(
      p,
      p + Offset(math.cos(dir - spread), math.sin(dir - spread)) * headLen,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// L'icône de l'app, telle qu'elle apparaît sur l'écran d'accueil.
class _QuietoIcon extends StatelessWidget {
  final double size;

  const _QuietoIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.045),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.225),
        child: Image.asset('assets/images/Logo 1.jpeg', fit: BoxFit.cover),
      ),
    );
  }
}
