import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const _base = TextStyle(
    fontFamily: 'SF Pro Display',
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );

  /// Titre d'écran principal
  static final displayLarge = _base.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  /// Titre de section
  static final titleLarge = _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Titre de carte
  static final titleMedium = _base.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Corps principal
  static final bodyLarge = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Corps secondaire
  static final bodyMedium = _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textMuted,
  );

  /// Label bouton
  static final labelLarge = _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  /// Caption / métadonnées
  static final caption = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
  );

  /// Durée / badge
  static final badge = _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.accent,
  );
}
