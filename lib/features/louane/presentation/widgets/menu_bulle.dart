import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../../core/theme/app_text_styles.dart';
import '../../data/louane_message.dart';
import 'message_bubble.dart';

/// Le MENU CONTEXTUEL d'une bulle (demande de Paul, 22/09/2026 : « exactement
/// comme dans l'app Claude »). Appui long sur une bulle → petite vibration,
/// le reste du fil se floute et s'assombrit, la bulle reste à sa place,
/// légèrement gonflée, nette au-dessus du voile, et le popup sort de son
/// coin avec un ressort : en-tête date et heure, puis les actions. Si la
/// bulle est trop bas pour que le popup tienne, l'ensemble remonte.
/// Toucher à côté referme, à rebours.
class ActionBulle {
  final String valeur;
  final IconData icone;
  final String libelle;
  final bool danger;

  const ActionBulle(
    this.valeur,
    this.icone,
    this.libelle, {
    this.danger = false,
  });
}

/// Ouvre le menu sur la bulle dont [rect] est le rectangle écran (mesuré par
/// [MessageBubble]). Renvoie la valeur de l'action choisie, ou null.
Future<String?> montrerMenuBulle(
  BuildContext context, {
  required Rect rect,
  required LouaneMessage message,
  required List<ActionBulle> actions,
  bool premierDuGroupe = true,
  bool dernierDuGroupe = true,
  bool ample = false,
}) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    _MenuBulleRoute(
      rect: rect,
      message: message,
      actions: actions,
      premierDuGroupe: premierDuGroupe,
      dernierDuGroupe: dernierDuGroupe,
      ample: ample,
    ),
  );
}

const _mois = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];

/// « 15 sept. 2026 à 16:50 ». Publique pour le test.
String formaterDateMessage(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${_mois[d.month - 1]} ${d.year} à $h:$m';
}

class _MenuBulleRoute extends PopupRoute<String> {
  final Rect rect;
  final LouaneMessage message;
  final List<ActionBulle> actions;
  final bool premierDuGroupe;
  final bool dernierDuGroupe;
  final bool ample;

  _MenuBulleRoute({
    required this.rect,
    required this.message,
    required this.actions,
    required this.premierDuGroupe,
    required this.dernierDuGroupe,
    required this.ample,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fermer le menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 400);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 230);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _MenuBulleVue(
      animation: animation,
      rect: rect,
      message: message,
      actions: actions,
      premierDuGroupe: premierDuGroupe,
      dernierDuGroupe: dernierDuGroupe,
      ample: ample,
    );
  }
}

class _MenuBulleVue extends StatelessWidget {
  final Animation<double> animation;
  final Rect rect;
  final LouaneMessage message;
  final List<ActionBulle> actions;
  final bool premierDuGroupe;
  final bool dernierDuGroupe;
  final bool ample;

  const _MenuBulleVue({
    required this.animation,
    required this.rect,
    required this.message,
    required this.actions,
    required this.premierDuGroupe,
    required this.dernierDuGroupe,
    required this.ample,
  });

  static const _largeurMenu = 262.0;
  static const _hauteurEnTete = 40.0;
  static const _hauteurAction = 46.0;
  static const _ecart = 10.0;

  /// La bulle gonfle un peu (comme sous le doigt) et garde sa place.
  static const gonflement = 1.04;

  @override
  Widget build(BuildContext context) {
    final ecran = MediaQuery.sizeOf(context);
    final marges = MediaQuery.paddingOf(context);
    final estLouane = message.estLouane;
    final largeurMenu = _largeurMenu.clamp(0.0, ecran.width - 32);
    final hauteurMenu = _hauteurEnTete + _hauteurAction * actions.length + 6;
    // Si le popup ne tient pas sous la bulle, tout remonte (sans passer
    // sous l'en-tête pour autant).
    final basDispo = ecran.height - marges.bottom - 16;
    var decalage = (rect.bottom + _ecart + hauteurMenu - basDispo).clamp(
      0.0,
      double.infinity,
    );
    final hautMin = marges.top + 60;
    if (rect.top - decalage < hautMin) {
      decalage = (rect.top - hautMin).clamp(0.0, double.infinity);
    }
    final gauche = (estLouane ? rect.left : rect.right - largeurMenu).clamp(
      16.0,
      ecran.width - 16 - largeurMenu,
    );

    // Material transparent : sans lui, le texte redessiné hors de la page
    // (route de superposition) prend le style « sans Material » de Flutter,
    // souligné de jaune.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final v = animation.value;
          final t = Curves.easeOutCubic.transform(v);
          final ressort = Curves.easeOutBack.transform(v);
          final montee = decalage * t;
          return Stack(
            fit: StackFit.expand,
            children: [
              // Le reste du fil : flou et sombre, et laisse passer le toucher
              // (la barrière du dessous referme le menu).
              IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18 * t, sigmaY: 18 * t),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.42 * t),
                  ),
                ),
              ),
              // La bulle, nette, à sa place (un peu remontée si besoin), avec
              // une ombre qui la détache du fond.
              Positioned(
                left: rect.left,
                top: rect.top - montee,
                width: rect.width,
                height: rect.height,
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: gonflement,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.38 * t),
                            blurRadius: 26,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: BulleTexte(
                        message: message,
                        premierDuGroupe: premierDuGroupe,
                        dernierDuGroupe: dernierDuGroupe,
                        ample: ample,
                        sansMarge: true,
                      ),
                    ),
                  ),
                ),
              ),
              // Le popup sort du coin de la bulle, avec un ressort.
              Positioned(
                left: gauche,
                top: rect.bottom + _ecart - montee,
                width: largeurMenu,
                child: Opacity(
                  opacity: (v * 1.8).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.55 + 0.45 * ressort,
                    alignment: estLouane
                        ? Alignment.topLeft
                        : Alignment.topRight,
                    child: _PanneauMenu(
                      enTete: message.date == null
                          ? null
                          : formaterDateMessage(message.date!),
                      actions: actions,
                      onChoix: (valeur) {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop(valeur);
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Le panneau : verre sombre, en-tête discret, une ligne par action.
class _PanneauMenu extends StatelessWidget {
  final String? enTete;
  final List<ActionBulle> actions;
  final ValueChanged<String> onChoix;

  const _PanneauMenu({
    required this.enTete,
    required this.actions,
    required this.onChoix,
  });

  @override
  Widget build(BuildContext context) {
    final texte = AppTextStyles.bodyLarge.copyWith(
      color: Colors.white.withValues(alpha: 0.94),
      fontSize: 16.5,
      height: 1.2,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF17243B).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (enTete != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    enTete!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.45),
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => onChoix(actions[i].valeur),
                    splashColor: Colors.white.withValues(alpha: 0.06),
                    highlightColor: Colors.white.withValues(alpha: 0.06),
                    child: SizedBox(
                      height: 46,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(
                              actions[i].icone,
                              size: 21,
                              color: actions[i].danger
                                  ? const Color(0xFFFF8A80)
                                  : Colors.white.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                actions[i].libelle,
                                style: actions[i].danger
                                    ? texte.copyWith(
                                        color: const Color(0xFFFF8A80),
                                      )
                                    : texte,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
