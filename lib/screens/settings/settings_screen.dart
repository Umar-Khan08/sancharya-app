import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_language_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../models/farmer_user.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';
import '../language/language_selection_screen.dart';

/// Settings & User Preferences Screen
class SettingsScreen extends StatefulWidget {
  final bool isEmbedded;

  const SettingsScreen({super.key, this.isEmbedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  FarmerUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final authRepo = context.read<AuthRepository>();
    final user = await authRepo.getCurrentUser();
    if (mounted) setState(() => _currentUser = user);
  }

  Future<void> _handleLogout() async {
    final authRepo = context.read<AuthRepository>();
    await authRepo.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final langProvider = context.watch<AppLanguageProvider>();
    final isHindi = langProvider.isHindi;

    final content = SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title
          Text(
            loc.settingsTitle,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 20),

          // 1. Language Preference Section
          SectionHeader(
            title: loc.languageSetting,
            icon: Icons.translate_rounded,
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionScreen(isFromSettings: true),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreenLight.withAlpha(35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
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
                        loc.languageSetting,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHindi ? 'हिंदी (Hindi)' : 'English',
                        style: const TextStyle(
                          color: AppColors.primaryGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Farmer Profile Section
          SectionHeader(
            title: loc.profileSection,
            icon: Icons.person_outline_rounded,
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileRow(
                  loc.fullName,
                  _currentUser?.name ?? 'Kisan Mitra',
                  Icons.person_rounded,
                ),
                const Divider(),
                _buildProfileRow(
                  loc.registeredPhone,
                  _currentUser?.phone ?? '9876543210',
                  Icons.phone_rounded,
                ),
                const Divider(),
                _buildProfileRow(
                  loc.locationSetting,
                  _currentUser?.district ?? 'Nashik, Maharashtra',
                  Icons.location_on_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Data Architecture Notice
          SectionHeader(
            title: loc.simulatedDataDisclaimerTitle,
            icon: Icons.architecture_rounded,
          ),
          const SizedBox(height: 8),
          AppCard(
            backgroundColor: AppColors.demoBadgeBg,
            border: Border.all(color: AppColors.demoBadgeBorder, width: 1.2),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      color: AppColors.demoBadgeText,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.demoModeBanner,
                        style: const TextStyle(
                          color: AppColors.demoBadgeText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  loc.demoNoticeText,
                  style: TextStyle(
                    color: AppColors.demoBadgeText.withAlpha(230),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Architecture modularized with IAgricultureService and IResourceService interfaces\n• Ready to connect Python FastAPI ML inference endpoints, live AGMARKNET mandi feeds, and cold storage databases',
                  style: TextStyle(
                    color: AppColors.demoBadgeText,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 4. About SANCHARYA
          SectionHeader(
            title: loc.aboutSection,
            icon: Icons.info_outline_rounded,
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: AppColors.deepGreen,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.appTagline,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.appDescription,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      loc.versionLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      'v${AppConstants.appVersion} (Sprint 1 Production Ready)',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Log Out / Switch User Button
          AppButton(
            label: loc.logoutButton,
            variant: AppButtonVariant.outline,
            icon: Icons.logout_rounded,
            onPressed: _handleLogout,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: Text(loc.settingsTitle),
      ),
      body: content,
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
