import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'app_card.dart';

/// Interactive tile for selecting language (English / Hindi)
class LanguageSelectorTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String nativeScriptSample;
  final bool isSelected;
  final VoidCallback onTap;

  const LanguageSelectorTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.nativeScriptSample,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderRadius: 16,
      border: Border.all(
        color: isSelected ? AppColors.primaryGreen : AppColors.borderLight,
        width: isSelected ? 2.0 : 1.0,
      ),
      backgroundColor: isSelected
          ? AppColors.primaryGreenLight.withAlpha(20)
          : AppColors.white,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                nativeScriptSample,
                style: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.primaryGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isSelected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: isSelected ? AppColors.primaryGreen : AppColors.textTertiary,
            size: 26,
          ),
        ],
      ),
    );
  }
}
