import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';
import '../../data/demo_data/demo_mandi_prices.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';

/// Screen displaying daily Mandi price watch across APMC market yards
class MarketResourcesScreen extends StatelessWidget {
  final bool isEmbedded;

  const MarketResourcesScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isHindi = loc.isHindi;
    final records = DemoMandiPrices.records;

    final content = ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      itemCount: records.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Top Notice Header
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppBadge.demoBanner(text: loc.demoModeBanner),
                const SizedBox(height: 10),
                Text(
                  loc.mandiWatchTitle,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.mandiWatchSubtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }

        final item = records[index - 1];
        final isUp = item.trend == 'up';
        final isDown = item.trend == 'down';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreenLight.withAlpha(35),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isHindi ? item.cropNameHi : item.cropNameEn,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              isHindi ? item.mandiNameHi : item.mandiNameEn,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isUp
                            ? AppColors.riskLowBg
                            : isDown
                                ? AppColors.riskHighBg
                                : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isUp
                                ? Icons.arrow_upward_rounded
                                : isDown
                                    ? Icons.arrow_downward_rounded
                                    : Icons.horizontal_rule_rounded,
                            size: 14,
                            color: isUp
                                ? AppColors.riskLow
                                : isDown
                                    ? AppColors.riskHigh
                                    : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            item.arrivalQuintals,
                            style: TextStyle(
                              color: isUp
                                  ? AppColors.riskLow
                                  : isDown
                                      ? AppColors.riskHigh
                                      : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _priceColumn(
                      loc.minPrice,
                      '₹${item.minPrice.toStringAsFixed(0)}',
                      AppColors.textSecondary,
                    ),
                    _priceColumn(
                      loc.modalPrice,
                      '₹${item.modalPrice.toStringAsFixed(0)}',
                      AppColors.primaryGreen,
                      isBold: true,
                    ),
                    _priceColumn(
                      loc.maxPrice,
                      '₹${item.maxPrice.toStringAsFixed(0)}',
                      AppColors.textDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(loc.mandiWatchTitle),
      ),
      body: content,
    );
  }

  Widget _priceColumn(String label, String value, Color color, {bool isBold = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
