import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart' show StandardMessageCodec;

/// Le VERRE d'Apple (Liquid Glass, iOS 26) sous un [child] — demande de Paul,
/// 22/09/2026 : « l'effet glace d'Apple, comme dans l'app Claude ». Sur
/// iPhone, une vue native (VerreChannel.swift) fait le fond : ce qui est
/// derrière se voit au travers, déformé et flouté, avec le reflet sur les
/// bords ; Flutter dessine [child] par-dessus. Ailleurs (Android) : un flou
/// Flutter teinté, comme avant.
class VerreApple extends StatelessWidget {
  final double rayon;

  /// True : verre sans teinte, clair et transparent (Claude). False : teinté
  /// bleu nuit, plus proche des cartes de l'app.
  final bool clair;
  final Widget child;

  const VerreApple({
    super.key,
    this.rayon = 28,
    this.clair = true,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bords = BorderRadius.circular(rayon);
    if (!Platform.isIOS) {
      return ClipRRect(
        borderRadius: bords,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF122036).withValues(alpha: 0.85),
              borderRadius: bords,
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: child,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: bords,
      child: Stack(
        children: [
          Positioned.fill(
            child: UiKitView(
              viewType: 'quieto/verre',
              creationParams: <String, Object>{'rayon': rayon, 'clair': clair},
              creationParamsCodec: const StandardMessageCodec(),
              // Le verre ne prend jamais le toucher : le champ et les boutons
              // sont à Flutter.
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            ),
          ),
          child,
        ],
      ),
    );
  }
}
