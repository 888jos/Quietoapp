import 'package:flutter/material.dart';
import '../config/app_constants.dart';
import '../theme/app_colors.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? AppConstants.radiusMd;

    return Material(
      color: color ?? AppColors.cardSurface,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.accentDim,
        child: Padding(
          padding: padding ??
              const EdgeInsets.all(AppConstants.spacingMd),
          child: child,
        ),
      ),
    );
  }
}
