import 'package:flutter/material.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';

class OnboardingProgressBar extends StatelessWidget {
  final int current;
  final int total;

  const OnboardingProgressBar({
    super.key,
    required this.current,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i <= current;
        return Expanded(
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: AppConstants.animFast),
            height: 3,
            margin: EdgeInsets.only(
                right: i < total - 1 ? AppConstants.spacingXs : 0),
            decoration: BoxDecoration(
              color: active ? AppColors.accent : AppColors.accentDim,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
