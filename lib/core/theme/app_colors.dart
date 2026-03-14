import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Fond principal — bleu nuit
  static const background = Color(0xFF0A1628);

  /// Surface des cartes
  static const cardSurface = Color(0xFF0D2137);

  /// Accent principal — turquoise
  static const accent = Color(0xFF5CE0D8);

  /// Accent à 15% d'opacité — éléments subtils
  static const accentDim = Color(0x265CE0D8);

  /// Texte principal
  static const textPrimary = Color(0xFFFFFFFF);

  /// Texte secondaire (60% opacité)
  static const textMuted = Color(0x99FFFFFF);

  /// Couleur d'erreur
  static const error = Color(0xFFE07070);
}
