import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'app_button.dart';

/// Reusable error message view with retry trigger
class ErrorStateView extends StatelessWidget {
  final String title;
  final String message;
  final String? retryLabel;
  final VoidCallback? onRetry;

  const ErrorStateView({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.riskHighBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.riskHigh,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              AppButton(
                label: retryLabel ?? 'Try Again',
                onPressed: onRetry,
                variant: AppButtonVariant.primaryGreen,
                icon: Icons.refresh_rounded,
                width: 180,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
