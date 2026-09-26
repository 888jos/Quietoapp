import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'fade_page_transitions_builder.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.accent,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          secondary: AppColors.accent,
          surface: AppColors.cardSurface,
          error: AppColors.error,
          onPrimary: AppColors.background,
          onSecondary: AppColors.background,
          onSurface: AppColors.textPrimary,
          onError: AppColors.textPrimary,
        ),
        textTheme: TextTheme(
          displayLarge: AppTextStyles.displayLarge,
          titleLarge: AppTextStyles.titleLarge,
          titleMedium: AppTextStyles.titleMedium,
          bodyLarge: AppTextStyles.bodyLarge,
          bodyMedium: AppTextStyles.bodyMedium,
          labelLarge: AppTextStyles.labelLarge,
          bodySmall: AppTextStyles.caption,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: AppTextStyles.titleMedium,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.cardSurface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.cardSurface,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.accentDim,
          thickness: 1,
        ),
        // Transitions d'écran en fade-in/out doux sur toutes les plateformes,
        // au lieu du slide horizontal iOS sec qui jurait avec l'ambiance calme.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: FadePageTransitionsBuilder(),
            TargetPlatform.android: FadePageTransitionsBuilder(),
            TargetPlatform.macOS: FadePageTransitionsBuilder(),
            TargetPlatform.windows: FadePageTransitionsBuilder(),
            TargetPlatform.linux: FadePageTransitionsBuilder(),
            TargetPlatform.fuchsia: FadePageTransitionsBuilder(),
          },
        ),
        useMaterial3: true,
      );
}
