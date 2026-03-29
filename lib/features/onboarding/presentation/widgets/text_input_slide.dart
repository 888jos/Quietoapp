import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class TextInputSlide extends StatefulWidget {
  final String question;
  final String hint;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final VoidCallback? onSubmitted;

  const TextInputSlide({
    super.key,
    required this.question,
    required this.hint,
    required this.onChanged,
    this.initialValue = '',
    this.onSubmitted,
  });

  @override
  State<TextInputSlide> createState() => _TextInputSlideState();
}

class _TextInputSlideState extends State<TextInputSlide> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.question,
          style: AppTextStyles.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingXl),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: AppTextStyles.bodyLarge,
          maxLength: 30,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'^\s+')),
          ],
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodyMedium,
            counterText: '',
            filled: true,
            fillColor: AppColors.cardSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingMd,
              vertical: AppConstants.spacingMd,
            ),
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(AppConstants.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
          textInputAction: widget.onSubmitted != null
              ? TextInputAction.done
              : TextInputAction.none,
          onChanged: widget.onChanged,
          onSubmitted: (_) => widget.onSubmitted?.call(),
        ),
      ],
    );
  }
}
