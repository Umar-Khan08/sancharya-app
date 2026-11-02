import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/localization/app_localizations.dart';
import '../models/crop_analysis_result.dart';

/// Visually distinct badge representing crop spoilage risk level
class RiskLevelBadge extends StatelessWidget {
  final SpoilageRiskLevel riskLevel;
  final bool showIcon;

  const RiskLevelBadge({
    super.key,
    required this.riskLevel,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    Color bg;
    Color textColor;
    IconData icon;
    String label;

    switch (riskLevel) {
      case SpoilageRiskLevel.low:
        bg = AppColors.riskLowBg;
        textColor = AppColors.riskLow;
        icon = Icons.check_circle_outline_rounded;
        label = loc.riskLow;
        break;
      case SpoilageRiskLevel.medium:
        bg = AppColors.riskMediumBg;
        textColor = AppColors.riskMedium;
        icon = Icons.warning_amber_rounded;
        label = loc.riskMedium;
        break;
      case SpoilageRiskLevel.high:
        bg = AppColors.riskHighBg;
        textColor = AppColors.riskHigh;
        icon = Icons.dangerous_outlined;
        label = loc.riskHigh;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withAlpha(60), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, color: textColor, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
