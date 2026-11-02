/// General application constants for SANCHARYA
class AppConstants {
  AppConstants._();

  static const String appName = 'SANCHARYA';
  static const String appTaglineEn = 'Smart Agriculture Decision Support';
  static const String appTaglineHi = 'स्मार्ट कृषि निर्णय सहायता';
  static const String appVersion = '1.0.0';

  // Shared Preferences Keys
  static const String keyLanguageCode = 'sancharya_selected_language';
  static const String keyIsFirstRun = 'sancharya_is_first_run';
  static const String keyUserLoggedIn = 'sancharya_user_logged_in';
  static const String keyUserName = 'sancharya_user_name';
  static const String keyUserPhone = 'sancharya_user_phone';

  // Demo Banner Notice
  static const String demoNoticeEn = 
      'Demonstration Mode: Using simulated agricultural benchmarks. Connect live datasets or API endpoints in production.';
  static const String demoNoticeHi = 
      'प्रदर्शन मोड: अनुमानित कृषि बेंचमार्क का उपयोग हो रहा है। उत्पादन में वास्तविक डेटासेट या एपीआई से जोड़ें।';
}
