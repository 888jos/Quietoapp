import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/ui/colonne_tablette.dart';
import 'slide_reveal.dart';

class QuestionSlide extends StatelessWidget {
  final String question;
  final List<String> options;
  final String? selectedOption;
  final ValueChanged<String> onSelect;

  /// Vrai quand cette slide est affichée : déclenche la cascade d'entrée.
  final bool active;

  const QuestionSlide({
    super.key,
    required this.question,
    required this.options,
    required this.selectedOption,
    required this.onSelect,
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    // iPad (demande de Paul, 11/09) : les réponses ne sont plus des
    // « bâtonnets » sur toute la largeur — moins larges, plus hautes, texte
    // plus gros ; le titre de la question grossit aussi.
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
        const SizedBox(height: AppConstants.spacingXl),
        ...options.asMap().entries.map((entry) {
          final i = entry.key;
          final option = entry.value;
          final selected = option == selectedOption;
          return SlideReveal(
            active: active,
            delay: Duration(milliseconds: 130 + i * 85),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(option);
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
                      color: selected
                          ? AppColors.accentDim
                          : AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                      border: Border.all(
                        color: selected ? AppColors.accent : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      option,
                      style: styleReponse.copyWith(
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
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
