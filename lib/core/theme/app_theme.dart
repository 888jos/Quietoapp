import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgForest,
        primaryColor: AppColors.sage,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.sage,
          secondary: AppColors.sage,
          surface: AppColors.cardForest,
          error: AppColors.error,
          onPrimary: AppColors.bgForest,
          onSecondary: AppColors.bgForest,
          onSurface: AppColors.parchment,
          onError: AppColors.parchment,
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
          backgroundColor: AppColors.bgForest,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          titleTextStyle: AppTextStyles.titleMedium,
          iconTheme: const IconThemeData(color: AppColors.parchment),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.cardForest,
          selectedItemColor: AppColors.sage,
          unselectedItemColor: AppColors.parchmentMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.cardForest,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.sageDim,
          thickness: 1,
        ),
        useMaterial3: true,
      );
}
