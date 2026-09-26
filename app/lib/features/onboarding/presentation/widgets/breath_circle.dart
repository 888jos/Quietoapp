import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Cercle de respiration : gonfle 4 s (« Inspire… »), dégonfle 4 s
/// (« Expire… »). Utilisé sur l'écran d'accueil et la mini-respiration.
class BreathCircle extends StatefulWidget {
  final double size;
  final bool showLabel;

  const BreathCircle({super.key, this.size = 170, this.showLabel = true});

  @override
  State<BreathCircle> createState() => _BreathCircleState();
}

class _BreathCircleState extends State<BreathCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween(begin: 1.0, end: 1.35)
      .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          child: SizedBox(
            // Réserve la place du scale max pour ne pas pousser la mise en page.
            width: widget.size * 1.4,
            height: widget.size * 1.4,
            child: Center(
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accent.withValues(alpha: 0.35),
                      AppColors.accent.withValues(alpha: 0.08),
                      Colors.transparent,
                    ], stops: const [0.0, 0.6, 1.0]),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showLabel) ...[
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final inspire = _c.status == AnimationStatus.forward;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  inspire ? 'Inspire…' : 'Expire…',
                  // key = déclenche le fondu au changement de texte
                  key: ValueKey(inspire),
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
