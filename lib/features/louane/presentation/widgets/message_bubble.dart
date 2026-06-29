import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/louane_message.dart';
import '../louane_palette.dart';

/// Une bulle de message, façon messagerie. Louane à gauche (sombre),
/// l'utilisateur à droite (turquoise). Pas d'avatar par message : il vit
/// dans l'en-tête, comme une conversation WhatsApp en tête-à-tête.
///
/// [nouveau] : le message vient d'arriver → il « POP » (apparaît d'un coup
/// avec un petit rebond + fondu), comme en messagerie. L'animation ne se joue
/// QU'UNE fois (au montage) : pas de ré-animation lors des reconstructions.
class MessageBubble extends StatefulWidget {
  final LouaneMessage message;
  final bool nouveau;

  const MessageBubble({
    super.key,
    required this.message,
    this.nouveau = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    // Anime seulement si le message est neuf ; sinon il est déjà « posé ».
    if (widget.nouveau) {
      _c.forward();
    } else {
      _c.value = 1.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estLouane = widget.message.estLouane;
    final largeurMax = MediaQuery.of(context).size.width * 0.78;

    final texteStyle = AppTextStyles.bodyLarge.copyWith(
      color: estLouane ? AppColors.textPrimary : AppColors.background,
      height: 1.45,
    );

    final bulle = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
      child: Text(widget.message.texte, style: texteStyle),
    );

    final contenu = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      alignment: estLouane ? Alignment.centerLeft : Alignment.centerRight,
      child: bulle,
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        // POP : petit rebond (scale) + fondu, depuis le côté de l'expéditeur.
        final pop = Curves.easeOutBack.transform(_c.value);
        return Opacity(
          opacity: _c.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.75 + 0.25 * pop,
            alignment:
                estLouane ? Alignment.bottomLeft : Alignment.bottomRight,
            child: child,
          ),
        );
      },
      child: contenu,
    );
  }
}

/// Bulle "Louane écrit…" : 3 points qui pulsent doucement, à gauche.
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
      margin: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.centerLeft,
      child: Container(
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
    );
  }
}
