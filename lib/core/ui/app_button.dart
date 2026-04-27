import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum AppButtonVariant { primary, secondary, ghost }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool fullWidth;
  final IconData? leadingIcon;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.fullWidth = true,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null || isLoading;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: AnimatedOpacity(
        duration:
            const Duration(milliseconds: AppConstants.animFast),
        opacity: isDisabled ? 0.5 : 1.0,
        child: Material(
          color: _backgroundColor,
          borderRadius:
              BorderRadius.circular(AppConstants.radiusLg),
          child: InkWell(
            onTap: isDisabled
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    onTap!();
                  },
            borderRadius:
                BorderRadius.circular(AppConstants.radiusLg),
            splashColor: AppColors.accentDim,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spacingMd,
                horizontal: AppConstants.spacingLg,
              ),
              decoration: variant == AppButtonVariant.secondary
                  ? BoxDecoration(
                      border: Border.all(
                          color: AppColors.accent, width: 1.5),
                      borderRadius: BorderRadius.circular(
                          AppConstants.radiusLg),
                    )
                  : null,
              child: Row(
                mainAxisSize:
                    fullWidth ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.background,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spacingSm),
                  ] else if (leadingIcon != null) ...[
                    Icon(leadingIcon,
                        size: 18, color: _foregroundColor),
                    const SizedBox(width: AppConstants.spacingSm),
                  ],
                  Text(label,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: _foregroundColor)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _backgroundColor => switch (variant) {
        AppButtonVariant.primary => AppColors.accent,
        AppButtonVariant.secondary => Colors.transparent,
        AppButtonVariant.ghost => Colors.transparent,
      };

  Color get _foregroundColor => switch (variant) {
        AppButtonVariant.primary => AppColors.background,
        AppButtonVariant.secondary => AppColors.accent,
        AppButtonVariant.ghost => AppColors.textMuted,
      };
}
