import 'package:flutter/material.dart';

/// Révèle son [child] en fondu + léger glissement vers le haut dès que [active]
/// devient vrai. Empiler plusieurs SlideReveal avec des [delay] croissants
/// crée une apparition en cascade (staggered).
///
/// Pensé pour vivre dans un PageView : les slides voisines sont déjà montées
/// mais restent invisibles tant qu'elles ne sont pas actives ; l'animation ne
/// se déclenche donc qu'à l'arrivée réelle sur la slide.
class SlideReveal extends StatefulWidget {
  final bool active;
  final Duration delay;
  final Widget child;

  const SlideReveal({
    super.key,
    required this.active,
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<SlideReveal> createState() => _SlideRevealState();
}

class _SlideRevealState extends State<SlideReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.active) _play();
  }

  @override
  void didUpdateWidget(covariant SlideReveal old) {
    super.didUpdateWidget(old);
    // Rejoue la cascade à chaque fois que la slide (re)devient active.
    if (widget.active && !old.active) {
      _c.value = 0;
      _play();
    }
  }

  void _play() {
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
