import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/colonne_tablette.dart';
import '../../data/louane_message.dart';
import '../louane_palette.dart';

/// Teinte des bulles de Louane : un demi-ton plus claire que les cartes,
/// pour se détacher du fond de nuit (retour de Paul, 12/09).
const Color kBulleLouane = Color(0xFF122847);

/// Une bulle de message, façon messagerie. Louane à gauche (sombre),
/// l'utilisateur à droite (turquoise). Pas d'avatar par message : il vit
/// dans l'en-tête, comme une conversation WhatsApp en tête-à-tête.
///
/// [nouveau] : le message vient d'arriver → il « POP » (apparaît d'un coup
/// avec un petit rebond + fondu), comme en messagerie. L'animation ne se joue
/// QU'UNE fois (au montage) : pas de ré-animation lors des reconstructions.
///
/// [premierDuGroupe] / [dernierDuGroupe] : groupement façon Messages (Paul,
/// 12/09) — des bulles qui se suivent du même côté se serrent, et seuls les
/// coins extérieurs du groupe sont pleinement arrondis.
///
/// [depuisSaisie] : bulle de la personne qui vient d'être envoyée → elle se
/// détache de la pilule de saisie et monte prendre sa place, avec un petit
/// ressort (comme Messages), au lieu de simplement apparaître.
///
/// [onLongPress] (22/09/2026, « comme dans l'app Claude ») : sous le doigt,
/// la bulle gonfle doucement ; l'appui long fait une petite vibration et
/// appelle [onLongPress] avec le rectangle écran de la bulle (le menu
/// contextuel s'y accroche). Elle reste gonflée tant que la future rendue
/// n'est pas terminée (le menu ouvert), puis redescend.
class MessageBubble extends StatefulWidget {
  final LouaneMessage message;
  final bool nouveau;
  final bool premierDuGroupe;
  final bool dernierDuGroupe;
  final bool depuisSaisie;

  /// Sur iPad seulement : bulle plus large et texte plus gros (débrief de
  /// l'onboarding, qui doit se lire de loin — Paul, 11/09). Sans effet sur
  /// iPhone.
  final bool ample;

  final Future<void> Function(Rect rectBulle)? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    this.nouveau = false,
    this.ample = false,
    this.premierDuGroupe = true,
    this.dernierDuGroupe = true,
    this.depuisSaisie = false,
    this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with TickerProviderStateMixin {
  late final AnimationController _c;

  /// Le gonflement sous le doigt (0 → 1 = 1,00 → 1,04).
  late final AnimationController _pression;
  final GlobalKey _cleBulle = GlobalKey();
  Timer? _timerGonfle;
  bool _menuOuvert = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      // Le ressort de l'envoi prend un peu plus de temps que le POP.
      duration: Duration(milliseconds: widget.depuisSaisie ? 480 : 340),
    );
    _pression = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
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
    _timerGonfle?.cancel();
    _c.dispose();
    _pression.dispose();
    super.dispose();
  }

  // ── Sous le doigt ───────────────────────────────────────
  void _surAppui(TapDownDetails _) {
    if (widget.onLongPress == null) return;
    // Un court instant après la pose du doigt (un début de défilement
    // annule avant), la bulle se met à gonfler.
    _timerGonfle?.cancel();
    _timerGonfle = Timer(const Duration(milliseconds: 90), () {
      if (mounted && !_menuOuvert) _pression.forward();
    });
  }

  void _surRelache() {
    _timerGonfle?.cancel();
    if (!_menuOuvert) _pression.reverse();
  }

  Future<void> _surAppuiLong() async {
    final surAppuiLong = widget.onLongPress;
    if (surAppuiLong == null) return;
    final boite = _cleBulle.currentContext?.findRenderObject();
    if (boite is! RenderBox || !boite.attached || !boite.hasSize) return;
    _timerGonfle?.cancel();
    _menuOuvert = true;
    HapticFeedback.lightImpact();
    if (_pression.value < 1) unawaited(_pression.forward());
    final rect = boite.localToGlobal(Offset.zero) & boite.size;
    try {
      await surAppuiLong(rect);
    } finally {
      _menuOuvert = false;
      if (mounted) _pression.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final estLouane = widget.message.estLouane;
    final ample = widget.ample && Tablette.estTablette(context);
    final premier = widget.premierDuGroupe;
    final dernier = widget.dernierDuGroupe;

    Widget bulle = KeyedSubtree(
      key: _cleBulle,
      child: BulleTexte(
        message: widget.message,
        premierDuGroupe: premier,
        dernierDuGroupe: dernier,
        ample: ample,
        sansMarge: true,
      ),
    );
    if (widget.onLongPress != null) {
      bulle = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _surAppui,
        onTapUp: (_) => _surRelache(),
        onTapCancel: _surRelache,
        onLongPress: () => unawaited(_surAppuiLong()),
        child: AnimatedBuilder(
          animation: _pression,
          builder: (context, child) => Transform.scale(
            scale: 1 + 0.04 * Curves.easeOut.transform(_pression.value),
            child: child,
          ),
          child: bulle,
        ),
      );
    }

    final contenu = Container(
      // Serrées dans un groupe, aérées entre deux groupes.
      margin: EdgeInsets.only(top: premier ? 5 : 1.5, bottom: dernier ? 5 : 1.5),
      alignment: estLouane ? Alignment.centerLeft : Alignment.centerRight,
      child: bulle,
    );

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        if (widget.depuisSaisie) {
          // L'envoi : la bulle monte depuis la pilule de saisie (sous le
          // fil) avec un ressort, en grandissant un peu, et se pose.
          final ressort = Curves.easeOutBack.transform(_c.value);
          final montee = (1 - ressort) * 54;
          return Opacity(
            opacity: (_c.value * 2.5).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, montee),
              child: Transform.scale(
                scale: 0.88 + 0.12 * ressort,
                alignment: Alignment.bottomRight,
                child: child,
              ),
            ),
          );
        }
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

/// La bulle elle-même (fond, coins, texte), sans animation : ce que
/// [MessageBubble] anime, et ce que le menu contextuel redessine, nette,
/// au-dessus du fil flouté. [sansMarge] : sans les marges de groupe.
class BulleTexte extends StatelessWidget {
  final LouaneMessage message;
  final bool premierDuGroupe;
  final bool dernierDuGroupe;
  final bool ample;
  final bool sansMarge;

  const BulleTexte({
    super.key,
    required this.message,
    this.premierDuGroupe = true,
    this.dernierDuGroupe = true,
    this.ample = false,
    this.sansMarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final estLouane = message.estLouane;
    final ample = this.ample && Tablette.estTablette(context);
    final largeurMax =
        MediaQuery.of(context).size.width * (ample ? 0.96 : 0.78);
    final texteStyle = AppTextStyles.bodyLarge.copyWith(
      color: estLouane ? AppColors.textPrimary : AppColors.background,
      height: 1.45,
      fontSize: ample ? 19 : null,
    );
    // Coins façon Messages : du côté de l'expéditeur, seuls le haut du
    // premier et le bas du dernier restent pleinement ronds ; entre deux,
    // un petit rayon qui « coud » les bulles du groupe.
    final premier = premierDuGroupe;
    final dernier = dernierDuGroupe;
    const rond = Radius.circular(20);
    const couture = Radius.circular(7);
    const queue = Radius.circular(5);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: sansMarge
          ? EdgeInsets.zero
          : EdgeInsets.only(top: premier ? 5 : 1.5, bottom: dernier ? 5 : 1.5),
      padding: ample
          ? const EdgeInsets.symmetric(horizontal: 20, vertical: 14)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      constraints: BoxConstraints(maxWidth: largeurMax),
      decoration: BoxDecoration(
        color: estLouane ? kBulleLouane : LouanePalette.accent,
        borderRadius: estLouane
            ? BorderRadius.only(
                topLeft: premier ? rond : couture,
                topRight: rond,
                bottomLeft: dernier ? queue : couture,
                bottomRight: rond,
              )
            : BorderRadius.only(
                topLeft: rond,
                topRight: premier ? rond : couture,
                bottomLeft: rond,
                bottomRight: dernier ? queue : couture,
              ),
      ),
      child: Text(message.texte, style: texteStyle),
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
          color: kBulleLouane,
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
