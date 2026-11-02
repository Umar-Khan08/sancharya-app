import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../models/farmer_user.dart';
import '../../repositories/agriculture_repository.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/risk_level_badge.dart';
import '../../widgets/section_header.dart';
import '../../core/location/app_location_provider.dart';
import '../cold_storage/cold_storage_screen.dart';
import '../crop_analysis/crop_analysis_screen.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';
import '../settings/settings_screen.dart';
import '../language/language_selection_screen.dart';

/// Simple, Colorful & Farmer-Friendly Home Screen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  FarmerUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authRepo = context.read<AuthRepository>();
    final user = await authRepo.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // 4 Straightforward Destinations
    final screens = [
      _buildHomeDashboard(context, loc),
      const CropAnalysisScreen(isEmbedded: true),
      const ColdStorageScreen(isEmbedded: true),
      const SettingsScreen(isEmbedded: true),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppConstants.appName,
              style: TextStyle(
                color: AppColors.deepGreen,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.language_rounded, color: AppColors.primaryGreen),
            tooltip: loc.languageSetting,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(isFromSettings: true),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: AppColors.textDark),
            tooltip: loc.navProfile,
            onPressed: () {
              setState(() => _currentTabIndex = 3);
            },
          ),
        ],
      ),
      body: screens[_currentTabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTabIndex,
        onDestinationSelected: (index) {
          setState(() => _currentTabIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: loc.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics_rounded),
            label: loc.navAnalyze,
          ),
          NavigationDestination(
            icon: const Icon(Icons.warehouse_outlined),
            selectedIcon: const Icon(Icons.warehouse_rounded),
            label: loc.navResources,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: loc.navProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDashboard(BuildContext context, AppLocalizations loc) {
    final agriRepo = context.watch<AgricultureRepository>();

    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: () async {
        await _loadUser();
        setState(() {});
      },
      child: SingleChildScrollView(
        // ClampingScrollPhysics fixes the Android 12+ elastic stretching issue
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Welcome Section with Farmer Greeting
            AppCard(
              backgroundColor: AppColors.primaryGreen,
              border: Border.all(color: AppColors.primaryGreenDark, width: 1),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.white.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_rounded,
                        color: AppColors.white,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${loc.greetingFarmer}, ${_currentUser?.name ?? "Kisan Mitra"}',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          loc.homeSubtitle,
                          style: const TextStyle(
                            color: AppColors.accentYellow,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Active Farm Location Bar
            Builder(
              builder: (ctx) {
                final locProvider = ctx.watch<AppLocationProvider>();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        locProvider.isAutoDetected ? Icons.gps_fixed_rounded : Icons.location_on_rounded,
                        size: 16,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locProvider.hasUserLocation
                              ? locProvider.formattedLocation
                              : (loc.isHindi ? 'स्थान चुनें / ऑटो-डिटेक्ट करें' : 'Tap to set farm location'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: locProvider.hasUserLocation ? AppColors.textDark : AppColors.primaryGreen,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() => _currentTabIndex = 1);
                        },
                        child: Text(
                          loc.isHindi ? 'बदलें' : 'Change',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.resourceBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // B. Main Action Button: "ANALYZE YOUR CROP"
            AppCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppColors.white,
              border: Border.all(color: AppColors.accentYellowDark.withAlpha(90), width: 1.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellowLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.insights_rounded,
                          color: AppColors.accentYellowDark,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              loc.analyzeYourCropButton,
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              loc.startAnalysisPrompt,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: loc.analyzeYourCropButton,
                    variant: AppButtonVariant.goldenYellow,
                    icon: Icons.play_arrow_rounded,
                    onPressed: () {
                      setState(() => _currentTabIndex = 1);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // C. Restored Section: "WHAT SANCHARYA PROVIDES"
            SectionHeader(
              title: loc.whatSancharyaProvidesTitle,
              subtitle: loc.whatSancharyaProvidesSubtitle,
              icon: Icons.auto_awesome_rounded,
            ),
            const SizedBox(height: 10),

            // Card 1: Crop Price
            _buildInfoCard(
              title: loc.cardCropPriceTitle,
              description: loc.cardCropPriceDesc,
              icon: Icons.currency_rupee_rounded,
              iconColor: AppColors.primaryGreen,
              iconBgColor: AppColors.primaryGreenLight.withAlpha(35),
            ),
            const SizedBox(height: 12),

            // Card 2: Spoilage Risk
            _buildInfoCard(
              title: loc.cardSpoilageRiskTitle,
              description: loc.cardSpoilageRiskDesc,
              icon: Icons.shield_outlined,
              iconColor: AppColors.riskMedium,
              iconBgColor: AppColors.riskMediumBg,
            ),
            const SizedBox(height: 12),

            // Card 3: Nearby Resources
            _buildInfoCard(
              title: loc.cardNearbyResourcesTitle,
              description: loc.cardNearbyResourcesDesc,
              icon: Icons.warehouse_rounded,
              iconColor: AppColors.resourceBlue,
              iconBgColor: AppColors.resourceBlueLight,
            ),
            const SizedBox(height: 12),

            // Card 4: Smart Advice
            _buildInfoCard(
              title: loc.cardSmartAdviceTitle,
              description: loc.cardSmartAdviceDesc,
              icon: Icons.psychology_alt_rounded,
              iconColor: AppColors.accentYellowDark,
              iconBgColor: AppColors.accentYellowLight,
            ),
            const SizedBox(height: 12),

            // Card 5: NGO Donation Support
            _buildInfoCard(
              title: loc.ngoTitle,
              description: loc.ngoSubtitle,
              icon: Icons.volunteer_activism_rounded,
              iconColor: AppColors.primaryGreen,
              iconBgColor: AppColors.primaryGreenLight.withAlpha(35),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.ngoDonation);
              },
            ),
            const SizedBox(height: 24),

            // Recent Analyses Section
            SectionHeader(
              title: loc.recentAnalysesTitle,
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<CombinedCropAnalysisResult>>(
              future: agriRepo.getRecentAnalyses(userPhone: _currentUser?.phone),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    child: Center(
                      child: Text(
                        loc.isHindi
                            ? 'इतिहास लोड करने में असमर्थ। कृपया बाद में पुनः प्रयास करें।'
                            : 'Unable to load search history. Please try again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    child: Center(
                      child: Text(
                        loc.noRecentAnalyses,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: list.map((item) {
                    final isHindi = loc.isHindi;
                    final formattedDate = _formatHistoryDate(item.timestamp, isHindi);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: AppCard(
                        padding: const EdgeInsets.all(16),
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.cropResults,
                            arguments: item,
                          );
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.eco_rounded,
                                color: AppColors.primaryGreen,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.input.crop.localizedName(isHindi),
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${item.input.location} • $formattedDate • ${item.input.quantity.toStringAsFixed(0)} ${item.input.quantityUnit == QuantityUnit.kilogram ? "kg" : loc.quintalUnit}',
                                    style: const TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.recommendation.getHeadline(isHindi),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            RiskLevelBadge(
                              riskLevel: item.spoilageRisk.riskLevel,
                              showIcon: false,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHistoryDate(DateTime date, bool isHindi) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0 && date.day == now.day) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return isHindi ? 'आज $hour:$minute' : 'Today $hour:$minute';
    } else if (difference.inDays <= 1 && (now.day - date.day).abs() == 1) {
      return isHindi ? 'कल' : 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
