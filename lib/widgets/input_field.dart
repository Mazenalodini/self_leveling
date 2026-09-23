import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Themed text input with icon prefix, glow on focus.
class InputField extends StatefulWidget {
  final String? label;
  final String? placeholder;
  final IconData? prefixIcon;
  final Widget? suffixWidget;
  final bool obscureText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final String? errorText;
  final TextDirection? textDirection;
  final TextAlign textAlign;

  const InputField({
    super.key,
    this.label,
    this.placeholder,
    this.prefixIcon,
    this.suffixWidget,
    this.obscureText = false,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.onChanged,
    this.maxLines = 1,
    this.errorText,
    this.textDirection,
    this.textAlign = TextAlign.start,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() => _isFocused = _focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(
              widget.label!,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.errorText != null 
                          ? AppColors.danger.withOpacity(0.3)
                          : AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 20,
                    ),
                  ]
                : [],
          ),
          child: TextField(
              focusNode: _focusNode,
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              onChanged: widget.onChanged,
              maxLines: widget.maxLines,
              style: AppTextStyles.bodyMedium,
              textDirection: widget.textDirection,
              textAlign: widget.textAlign,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintTextDirection: widget.textDirection,
                prefixIcon: widget.prefixIcon != null
                    ? Padding(
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: Icon(
                          widget.prefixIcon,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      )
                    : null,
                suffixIcon: widget.suffixWidget != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: widget.suffixWidget,
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background.withOpacity(0.7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.primaryBlue.withOpacity(
                      _isFocused ? 1.0 : 0.2,
                    ),
                    width: 2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: widget.errorText != null ? AppColors.danger : AppColors.primaryBlue,
                    width: 2,
                  ),
                ),
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        if (widget.errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.errorText!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
