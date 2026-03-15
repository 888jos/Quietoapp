import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_text_styles.dart';

class IntroSlide extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;

  const IntroSlide({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 80)),
        const SizedBox(height: AppConstants.spacingXl),
        Text(
          title,
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingMd),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
