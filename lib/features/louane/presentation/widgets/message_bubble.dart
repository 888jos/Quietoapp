import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/louane_message.dart';
import '../louane_palette.dart';
import 'louane_avatar.dart';

/// Une bulle de message. Louane à gauche (sombre) avec son mini-avatar,
/// l'utilisateur à droite (turquoise).
///
/// [nouveau] : le message vient d'arriver → petite animation d'entrée
/// (glisse vers le haut + fondu), comme en messagerie.
/// [machineAEcrire] : le texte de Louane s'écrit progressivement, en direct
/// (réservé à son tout dernier message).
class MessageBubble extends StatelessWidget {
  final LouaneMessage message;
  final bool nouveau;
  final bool machineAEcrire;

  const MessageBubble({
    super.key,
    required this.message,
    this.nouveau = false,
    this.machineAEcrire = false,
  });

  @override
  Widget build(BuildContext context) {
    final estLouane = message.estLouane;
    final largeurMax = MediaQuery.of(context).size.width * 0.72;

    final texteStyle = AppTextStyles.bodyLarge.copyWith(
      color: estLouane ? AppColors.textPrimary : AppColors.background,
      height: 1.45,
    );

    final bulle = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(maxWidth: largeurMax),
      decoration: BoxDecoration(
        color: estLouane ? AppColors.cardSurface : LouanePalette.accent,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(estLouane ? 6 : 20),
          bottomRight: Radius.circular(estLouane ? 20 : 6),
        ),
      ),
      child: (estLouane && machineAEcrire)
          ? _TexteMachine(texte: message.texte, style: texteStyle)
          : Text(message.texte, style: texteStyle),
    );

    final Widget ligne = estLouane
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8, bottom: 2),
                child: LouaneAvatar(size: 30),
              ),
              Flexible(child: bulle),
            ],
          )
        : bulle;

    final contenu = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      alignment: estLouane ? Alignment.centerLeft : Alignment.centerRight,
      child: ligne,
    );

    if (!nouveau) return contenu;

    // Entrée façon messagerie : glisse vers le haut + fondu.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: contenu,
    );
  }
}

/// Texte qui s'écrit progressivement (effet « en train d'écrire »).
class _TexteMachine extends StatefulWidget {
  final String texte;
  final TextStyle style;
  const _TexteMachine({required this.texte, required this.style});

  @override
  State<_TexteMachine> createState() => _TexteMachineState();
}

class _TexteMachineState extends State<_TexteMachine> {
  int _n = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ~1 s pour révéler le message quelle que soit sa longueur (vivant, sans
    // traîner) : on adapte le nombre de caractères par tick.
    final pas = (widget.texte.length / 60).ceil().clamp(1, 6);
    _timer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted || _n >= widget.texte.length) {
        t.cancel();
        return;
      }
      setState(() => _n = (_n + pas).clamp(0, widget.texte.length));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.texte.substring(0, _n), style: widget.style);
  }
}

/// Bulle "Louane écrit…" : son avatar + 3 points qui pulsent doucement.
class TypingBubble extends StatefulWidget {
  const TypingBubble({super.key});

  @override
  State<TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 2),
            child: LouaneAvatar(size: 30, parle: true),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: const BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = (_c.value + i * 0.2) % 1.0;
                    final opacity =
                        0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
                    return Padding(
                      padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: LouanePalette.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
