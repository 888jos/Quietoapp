import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_button.dart';

class ErrorPlaceholder extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorPlaceholder({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Réessayer',
    this.icon = Icons.self_improvement,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppConstants.spacingLg),
              AppButton(
                label: retryLabel,
                onTap: onRetry,
                fullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
