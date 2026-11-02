import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Reusable contextual badge for demonstration status or facility labels
class AppBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const AppBadge({
    super.key,
    required this.text,
    this.icon,
    this.backgroundColor = AppColors.surfaceMuted,
    this.textColor = AppColors.textDark,
    this.borderColor,
  });

  factory AppBadge.demoBanner({required String text}) {
    return AppBadge(
      text: text,
      icon: Icons.science_outlined,
      backgroundColor: AppColors.demoBadgeBg,
      textColor: AppColors.demoBadgeText,
      borderColor: AppColors.demoBadgeBorder,
    );
  }

  factory AppBadge.resourceType({
    required String text,
    required IconData icon,
  }) {
    return AppBadge(
      text: text,
      icon: icon,
      backgroundColor: AppColors.resourceBlueLight,
      textColor: AppColors.resourceBlue,
      borderColor: AppColors.resourceBlue.withAlpha(50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? textColor.withAlpha(40),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
