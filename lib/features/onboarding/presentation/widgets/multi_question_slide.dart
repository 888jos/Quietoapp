import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'slide_reveal.dart';

/// Question à choix MULTIPLES (même style que QuestionSlide, mais on peut
/// cocher plusieurs réponses).
class MultiQuestionSlide extends StatelessWidget {
  final String question;
  final String? subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool active;

  const MultiQuestionSlide({
    super.key,
    required this.question,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.subtitle,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlideReveal(
          active: active,
          child: Text(
            question,
            style: AppTextStyles.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppConstants.spacingSm),
          SlideReveal(
            active: active,
            delay: const Duration(milliseconds: 80),
            child: Text(
              subtitle!,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: AppConstants.spacingXl),
        ...options.asMap().entries.map((entry) {
          final i = entry.key;
          final option = entry.value;
          final isSel = selected.contains(option);
          return SlideReveal(
            active: active,
            delay: Duration(milliseconds: 130 + i * 85),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onToggle(option);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: AppConstants.animFast),
                margin: const EdgeInsets.only(bottom: AppConstants.spacingMd),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingMd,
                  vertical: AppConstants.spacingMd,
                ),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.accentDim : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  border: Border.all(
                    color: isSel ? AppColors.accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  option,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: isSel ? AppColors.accent : AppColors.textPrimary,
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
