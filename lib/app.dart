import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/localization/app_language_provider.dart';
import 'core/location/app_location_provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/routing/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/sancharya_scroll_behavior.dart';
import 'models/crop_analysis_result.dart';
import 'repositories/agriculture_repository.dart';
import 'repositories/auth_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/cold_storage/cold_storage_screen.dart';
import 'screens/crop_analysis/crop_analysis_screen.dart';
import 'screens/crop_results/crop_results_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/language/language_selection_screen.dart';
import 'screens/market_resources/market_resources_screen.dart';
import 'screens/ngo/ngo_donation_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/agriculture/agmarknet_api_service.dart';
import 'services/auth/api_auth_service.dart';

/// Root application widget configuring dependency injection, themes, localization,
/// navigation, and non-stretching scroll behavior.
class SancharyaApp extends StatelessWidget {
  const SancharyaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Language & Localization state provider
        ChangeNotifierProvider<AppLanguageProvider>(
          create: (_) => AppLanguageProvider(),
        ),

        // Unified Location state provider
        ChangeNotifierProvider<AppLocationProvider>(
          create: (_) => AppLocationProvider(),
        ),

        // Agricultural intelligence repository with live Agmarknet API & fallback
        Provider<AgricultureRepository>(
          create: (_) => AgricultureRepository(AgmarknetAgricultureService()),
        ),

        // Authentication & farmer session repository
        Provider<AuthRepository>(
          create: (_) => AuthRepository(ApiAuthService()),
        ),
      ],
      child: Consumer<AppLanguageProvider>(
        builder: (context, langProvider, child) {
          return MaterialApp(
            title: 'SANCHARYA',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            // SancharyaScrollBehavior prevents Android 12+ elastic stretch distortion
            scrollBehavior: const SancharyaScrollBehavior(),
            locale: langProvider.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            initialRoute: AppRoutes.splash,
            routes: {
              AppRoutes.splash: (_) => const SplashScreen(),
              AppRoutes.language: (_) => const LanguageSelectionScreen(),
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.home: (_) => const HomeScreen(),
              AppRoutes.cropAnalysis: (_) => const CropAnalysisScreen(),
              AppRoutes.coldStorage: (_) => const ColdStorageScreen(),
              AppRoutes.marketResources: (_) => const MarketResourcesScreen(),
              AppRoutes.settings: (_) => const SettingsScreen(),
              AppRoutes.ngoDonation: (_) => const NgoDonationScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == AppRoutes.cropResults) {
                final args = settings.arguments as CombinedCropAnalysisResult;
                return MaterialPageRoute(
                  builder: (_) => CropResultsScreen(result: args),
                );
              }
              if (settings.name == AppRoutes.ngoDonation) {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (_) => NgoDonationScreen(
                    initialCrop: args?['crop'] as String?,
                    initialLocation: args?['location'] as String?,
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
