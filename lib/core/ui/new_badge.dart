import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NewBadge extends StatelessWidget {
  /// Texte affiché dans la pastille ('New !', 'Flash ⚡'…).
  final String label;

  const NewBadge({super.key, this.label = 'New !'});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.background,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
