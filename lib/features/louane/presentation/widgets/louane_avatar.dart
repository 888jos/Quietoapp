import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../louane_palette.dart';

/// Avatar animé de Louane : elle "respire" en continu, et s'illumine quand
/// elle écrit (= on la voit "parler"). Placeholder en attendant l'illustration
/// finale du personnage.
class LouaneAvatar extends StatefulWidget {
  final double size;
  final bool parle;

  const LouaneAvatar({super.key, this.size = 46, this.parle = false});

  @override
  State<LouaneAvatar> createState() => _LouaneAvatarState();
}

class _LouaneAvatarState extends State<LouaneAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value); // 0 → 1
        final scale = 1.0 + (widget.parle ? 0.06 : 0.03) * t;
        final glow = (widget.parle ? 0.45 : 0.18) + 0.25 * t;
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFB6F2EC), LouanePalette.accent],
              ),
              boxShadow: [
                BoxShadow(
                  color: LouanePalette.accent.withValues(alpha: glow),
                  blurRadius: widget.parle ? 18 : 10,
                  spreadRadius: widget.parle ? 1.5 : 0.5,
                ),
              ],
            ),
            child: CustomPaint(
              size: Size.square(widget.size),
              painter: _VisagePainter(),
            ),
          ),
        );
      },
    );
  }
}

class _VisagePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;

    // Yeux
    final rYeux = w * 0.045;
    canvas.drawCircle(Offset(w * 0.38, h * 0.44), rYeux, fill);
    canvas.drawCircle(Offset(w * 0.62, h * 0.44), rYeux, fill);

    // Sourire doux
    final stroke = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(
      center: Offset(w * 0.5, h * 0.5),
      radius: w * 0.17,
    );
    canvas.drawArc(rect, 0.3, 2.54, false, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
