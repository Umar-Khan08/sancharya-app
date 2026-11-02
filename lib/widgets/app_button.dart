import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum AppButtonVariant {
  primaryGreen,
  goldenYellow,
  outline,
  textOnly,
}

/// Farmer-friendly button with large touch target, clear contrast, and loading feedback.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primaryGreen,
    this.icon,
    this.isLoading = false,
    this.height = 54.0,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (isLoading) {
      content = const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
        ),
      );
    } else if (icon != null) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      content = Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      );
    }

    final boxConstraints = BoxConstraints(
      minHeight: height,
      minWidth: width ?? double.infinity,
    );

    switch (variant) {
      case AppButtonVariant.primaryGreen:
        return ConstrainedBox(
          constraints: boxConstraints,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.primaryGreen.withAlpha(150),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 1.5,
            ),
            child: content,
          ),
        );

      case AppButtonVariant.goldenYellow:
        return ConstrainedBox(
          constraints: boxConstraints,
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentYellow,
              foregroundColor: AppColors.deepGreen,
              disabledBackgroundColor: AppColors.accentYellow.withAlpha(150),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2.0,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            child: content,
          ),
        );

      case AppButtonVariant.outline:
        return ConstrainedBox(
          constraints: boxConstraints,
          child: OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              side: const BorderSide(color: AppColors.primaryGreen, width: 1.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: content,
          ),
        );

      case AppButtonVariant.textOnly:
        return TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
          ),
          child: content,
        );
    }
  }
}
