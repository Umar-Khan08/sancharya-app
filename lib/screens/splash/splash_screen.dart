import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_language_provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/routing/app_routes.dart';
import '../../repositories/auth_repository.dart';

/// Splash Screen for SANCHARYA
/// Displays branding, initializes language preference, and navigates to the appropriate screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _handleInitialNavigation();
  }

  Future<void> _handleInitialNavigation() async {
    // Allow splash branding display and ensure language preference is ready
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final langProvider = context.read<AppLanguageProvider>();
    if (!langProvider.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (!mounted) return;
    final authRepo = context.read<AuthRepository>();
    final user = await authRepo.getCurrentUser();

    if (!mounted) return;
    if (user != null) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      // Check if a saved language preference already exists
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final hasSavedLanguage = prefs.getString(AppConstants.keyLanguageCode) != null;
        if (hasSavedLanguage) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }
      } catch (_) {}
      if (!mounted) return;
      // First-time launch ever: Language Selection first
      Navigator.pushReplacementNamed(context, AppRoutes.language);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.deepGreen,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // App Logo Icon Graphic
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(50),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.agriculture_rounded,
                      color: AppColors.primaryGreen,
                      size: 54,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 8),
                // App Tagline
                Text(
                  loc.appTagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.accentYellow,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                // Subtle Loading
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.accentYellow),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  loc.pleaseWait,
                  style: TextStyle(
                    color: AppColors.white.withAlpha(180),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
