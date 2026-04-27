import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuestionSlide extends StatelessWidget {
  final String question;
  final List<String> options;
  final String? selectedOption;
  final ValueChanged<String> onSelect;

  const QuestionSlide({
    super.key,
    required this.question,
    required this.options,
    required this.selectedOption,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question,
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingXl),
        ...options.map((option) {
          final selected = option == selectedOption;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(option);
            },
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: AppConstants.animFast),
              margin: const EdgeInsets.only(
                  bottom: AppConstants.spacingMd),
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingMd,
                vertical: AppConstants.spacingMd,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.accentDim
                    : AppColors.cardSurface,
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(
                  color: selected
                      ? AppColors.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Text(
                option,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: selected
                      ? AppColors.accent
                      : AppColors.textPrimary,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }),
      ],
    );
  }
}
