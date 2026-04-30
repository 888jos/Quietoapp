import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/models/session_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ExpressCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;

  const ExpressCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Méditation express : ${session.title}, ${session.durationLabel}',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMd),
                  border:
                      Border.all(color: AppColors.accent, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      AppConstants.radiusMd - 1.5),
                  child: session.imageFile != null
                      ? Image.asset(
                          'assets/images/${session.imageFile}',
                          fit: BoxFit.cover,
                          errorBuilder: (context, e, stack) =>
                              _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                session.title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                session.durationLabel,
                style: AppTextStyles.badge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppColors.accentDim,
      child: const Icon(Icons.bolt_rounded,
          size: 40, color: AppColors.accent),
    );
  }
}
