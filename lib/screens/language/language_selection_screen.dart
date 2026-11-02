import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_language_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/app_button.dart';
import '../../widgets/language_selector_tile.dart';

/// Language Selection Screen
/// Supports English and Hindi with instant UI feedback and local persistence.
class LanguageSelectionScreen extends StatelessWidget {
  final bool isFromSettings;

  const LanguageSelectionScreen({
    super.key,
    this.isFromSettings = false,
  });

  @override
  Widget build(BuildContext context) {
    final langProvider = context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final isHindi = langProvider.isHindi;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: isFromSettings
          ? AppBar(
              title: Text(loc.languageSetting),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isFromSettings) ...[
                const SizedBox(height: 24),
                // App Logo Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: AppColors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AppConstants.appName,
                          style: TextStyle(
                            color: AppColors.deepGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          loc.appTagline,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],

              // Title & Subtitle
              Text(
                loc.selectLanguageTitle,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                loc.selectLanguageSubtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 32),

              // English Option
              LanguageSelectorTile(
                title: loc.englishLanguage,
                subtitle: loc.englishSubtitle,
                nativeScriptSample: 'EN',
                isSelected: !isHindi,
                onTap: () => langProvider.setLanguage('en'),
              ),
              const SizedBox(height: 16),

              // Hindi Option
              LanguageSelectorTile(
                title: loc.hindiLanguage,
                subtitle: loc.hindiSubtitle,
                nativeScriptSample: 'हिं',
                isSelected: isHindi,
                onTap: () => langProvider.setLanguage('hi'),
              ),
              const SizedBox(height: 40),

              // Confirmation Action Button
              AppButton(
                label: isFromSettings ? loc.save : loc.proceedInLanguage,
                variant: AppButtonVariant.goldenYellow,
                icon: Icons.check_circle_outline_rounded,
                onPressed: () async {
                  final authRepo = context.read<AuthRepository>();
                  final user = await authRepo.getCurrentUser();
                  if (!context.mounted) return;
                  if (isFromSettings || user != null || Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
