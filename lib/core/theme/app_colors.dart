import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Fond principal de l'app
  static const bgForest = Color(0xFF0D1F1A);

  /// Surface des cartes
  static const cardForest = Color(0xFF1A2E27);

  /// Accent principal
  static const sage = Color(0xFF7CAE9E);

  /// Sage à 15% d'opacité — éléments subtils
  static const sageDim = Color(0x267CAE9E);

  /// Texte principal
  static const parchment = Color(0xFFF5F0E8);

  /// Texte secondaire (60% opacité)
  static const parchmentMuted = Color(0x99F5F0E8);

  /// Couleur d'erreur
  static const error = Color(0xFFE07070);
}
