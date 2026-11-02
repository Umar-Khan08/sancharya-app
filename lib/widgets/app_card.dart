import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Reusable rounded card with soft shadows, accessible padding, and subtle borders.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final double elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.backgroundColor,
    this.border,
    this.borderRadius = 16.0,
    this.elevation = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: AppColors.borderLight,
              width: 1.0,
            ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepGreen.withAlpha((elevation * 12).round()),
            blurRadius: elevation * 4 + 4,
            offset: Offset(0, elevation * 1.5 + 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
