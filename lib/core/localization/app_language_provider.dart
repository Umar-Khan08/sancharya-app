import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Manages and persists the active application language (English or Hindi).
class AppLanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;
  bool get isHindi => _locale.languageCode == 'hi';

  AppLanguageProvider() {
    _loadLanguagePreference();
  }

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(AppConstants.keyLanguageCode);
      if (savedCode != null && (savedCode == 'en' || savedCode == 'hi')) {
        _locale = Locale(savedCode);
      }
    } catch (_) {
      // Graceful fallback to default English if storage read fails
      _locale = const Locale('en');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'hi') return;
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyLanguageCode, languageCode);
    } catch (_) {
      // Storage error handled silently
    }
  }

  Future<void> toggleLanguage() async {
    if (_locale.languageCode == 'en') {
      await setLanguage('hi');
    } else {
      await setLanguage('en');
    }
  }
}
