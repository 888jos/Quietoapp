import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Louane partage l'accent turquoise de Quieto, pour rester dans l'ambiance
/// « nuit étoilée » de l'app (plutôt qu'un accent à part).
abstract final class LouanePalette {
  /// Turquoise de Quieto — l'accent de Louane.
  static const accent = AppColors.accent;

  /// Turquoise très léger — pour les lueurs / fonds subtils.
  static const accentSoft = Color(0x225CE0D8);
}
