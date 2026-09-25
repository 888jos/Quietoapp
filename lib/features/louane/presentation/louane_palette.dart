import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Louane partage l'accent turquoise de Quieto, pour rester dans l'ambiance
/// « nuit étoilée » de l'app (plutôt qu'un accent à part).
abstract final class LouanePalette {
  /// Turquoise de Quieto — l'accent de Louane.
  static const accent = AppColors.accent;

  /// Turquoise très léger — pour les lueurs / fonds subtils.
  static const accentSoft = Color(0x225CE0D8);

  /// Fond du fil de conversation : uni, un cran plus sombre que le fond de
  /// l'app, pour que les bulles ressortent (Paul, 12/09 — pas de dégradé).
  static const fondChat = Color(0xFF07101F);
}
