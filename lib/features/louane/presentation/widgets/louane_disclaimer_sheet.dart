import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../louane_palette.dart';
import 'louane_avatar.dart';

/// Feuille « avant qu'on se parle » : Louane n'est pas une professionnelle de
/// santé, le 3114 et le 15 existent. Montrée UNE fois, à la première ouverture
/// de l'onglet. Non refermable autrement que par le bouton (c'est le point de
/// passage responsabilité du produit).
Future<void> montrerLouaneDisclaimer(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xCC050B14),
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 350),
    ),
    builder: (context) => const _FeuilleDisclaimer(),
  );
}

class _FeuilleDisclaimer extends StatelessWidget {
  const _FeuilleDisclaimer();

  @override
  Widget build(BuildContext context) {
    final basSafe = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0E1F38), AppColors.background],
        ),
      ),
      padding: EdgeInsets.fromLTRB(28, 32, 28, 20 + basSafe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LouaneAvatar(size: 72),
          const SizedBox(height: 20),
          Text(
            "Avant qu'on se parle",
            style: AppTextStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Je suis Louane. Je suis là pour t'écouter, sans jugement, autant "
            "que tu veux. Mais je dois être honnête avec toi : je ne suis pas "
            "une professionnelle de santé, et je ne remplace ni un médecin, "
            "ni un psychologue.",
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: LouanePalette.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              "Si un jour ça ne va vraiment pas : le 3114 (prévention "
              "suicide) t'écoute 24h/24, gratuitement. Et pour une urgence "
              "vitale, c'est le 15.",
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Pour tout le reste, je suis là 🤍",
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: LouanePalette.accent,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: Text(
                "J'ai compris",
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.background,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
