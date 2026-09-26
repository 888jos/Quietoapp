import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/colonne_tablette.dart';
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
    // iPad (demande de Paul, 11/09) : même traitement que QuestionSlide —
    // réponses moins larges et plus hautes, textes plus gros.
    final tablette = Tablette.estTablette(context);
    final largeurReponse = tablette ? 420.0 : double.infinity;
    final hauteurReponse = tablette ? 22.0 : AppConstants.spacingMd;
    final styleQuestion = tablette
        ? AppTextStyles.titleLarge.copyWith(fontSize: 28)
        : AppTextStyles.titleLarge;
    final styleReponse = tablette
        ? AppTextStyles.bodyLarge.copyWith(fontSize: 18)
        : AppTextStyles.bodyLarge;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SlideReveal(
          active: active,
          child: Text(
            question,
            style: styleQuestion,
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
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: largeurReponse),
                  child: AnimatedContainer(
                    width: double.infinity,
                    duration: const Duration(
                      milliseconds: AppConstants.animFast,
                    ),
                    margin: const EdgeInsets.only(
                      bottom: AppConstants.spacingMd,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingMd,
                      vertical: hauteurReponse,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AppColors.accentDim
                          : AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                      border: Border.all(
                        color: isSel ? AppColors.accent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      option,
                      style: styleReponse.copyWith(
                        color: isSel ? AppColors.accent : AppColors.textPrimary,
                        fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
