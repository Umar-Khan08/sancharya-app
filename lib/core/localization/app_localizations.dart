import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized localization for SANCHARYA
/// Provides English (en) and Hindi (hi) translations for all user-facing strings.
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
  ];

  bool get isHindi => locale.languageCode == 'hi';

  // Helper string retriever
  String _t(String en, String hi) => isHindi ? hi : en;

  // General & App Identity
  String get appName => 'SANCHARYA';
  String get appTagline => _t(
        'Smart Agriculture Decision Support',
        'स्मार्ट कृषि निर्णय सहायता',
      );
  String get appDescription => _t(
        'Empowering farmers with timely crop spoilage risk assessment, mandi market price predictions, and intelligent selling recommendations.',
        'किसानों को समय पर फसल खराब होने का जोखिम, मंडी भाव पूर्वानुमान और सही बिक्री निर्णय की शक्ति।',
      );
  String get demoModeBanner => _t(
        'Demonstration Mode • Simulated Benchmarks',
        'प्रदर्शन मोड • अनुमानित बेंचमार्क',
      );
  String get demoNoticeText => _t(
        'This release uses calibrated simulated models. Production versions will integrate live APEDA, AGMARKNET, and cold storage databases.',
        'यह संस्करण सिम्युलेटेड मॉडल पर आधारित है। उत्पादन संस्करण में एगमार्कनेट और वास्तविक कोल्ड स्टोरेज डेटा शामिल होगा।',
      );

  // Simplified Bottom Navigation
  String get navHome => _t('Home', 'होम');
  String get navAnalyze => _t('Analyze', 'विश्लेषण');
  String get navResources => _t('Resources', 'संसाधन');
  String get navProfile => _t('Profile', 'प्रोफ़ाइल');

  String get back => _t('Back', 'वापस');
  String get continueText => _t('Continue', 'आगे बढ़ें');
  String get cancel => _t('Cancel', 'रद्द करें');
  String get save => _t('Save', 'सहेजें');
  String get refresh => _t('Refresh', 'रिफ्रेश');

  // Language Selection Screen
  String get selectLanguageTitle => _t('Select Your Language', 'अपनी भाषा चुनें');
  String get selectLanguageSubtitle => _t(
        'Choose your preferred language for the SANCHARYA application. You can change this anytime from Settings.',
        'संचर्या ऐप के लिए अपनी पसंदीदा भाषा चुनें। आप इसे सेटिंग्स से कभी भी बदल सकते हैं।',
      );
  String get englishLanguage => 'English';
  String get englishSubtitle => 'Default international language';
  String get hindiLanguage => 'हिंदी (Hindi)';
  String get hindiSubtitle => 'भारतीय किसान अनुकूल भाषा';
  String get proceedInLanguage => _t('Proceed in English', 'हिंदी में आगे बढ़ें');

  // Auth / Login Screen & Phone OTP Verification
  String get welcomeTitle => _t('Welcome to SANCHARYA', 'संचर्या में आपका स्वागत है');
  String get welcomeSubtitle => _t(
        'Your trusted smart farming companion for market intelligence and post-harvest management.',
        'बाज़ार समझ और फसल कटाई उपरांत प्रबंधन के लिए आपका विश्वसनीय साथी।',
      );
  String get enterMobileNumber => _t('Mobile Number', 'मोबाइल नंबर');
  String get mobileNumberHint => _t('Enter 10-digit mobile number', '10 अंकों का मोबाइल नंबर दर्ज करें');
  String get fullName => _t('Farmer Name', 'किसान का नाम');
  String get fullNameHint => _t('e.g. Ramesh Kumar', 'उदा. रमेश कुमार');
  String get districtState => _t('District / Region', 'जिला / क्षेत्र');
  String get districtStateHint => _t('e.g. Nashik, Maharashtra', 'उदा. नासिक, महाराष्ट्र');
  
  String get sendOtpButton => _t('Send OTP', 'ओटीपी भेजें');
  String get verifyOtpButton => _t('Verify & Sign In', 'सत्यापित कर आगे बढ़ें');
  String get enterOtpTitle => _t('Enter Verification Code', 'सत्यापन कोड दर्ज करें');
  String get enterOtpSubtitle => _t(
        'Enter the 6-digit verification code sent to your mobile number',
        'अपने मोबाइल नंबर पर भेजा गया 6 अंकों का सत्यापन कोड दर्ज करें',
      );
  String get editMobile => _t('Change Number', 'नंबर बदलें');
  String get resendOtpPrompt => _t('Resend OTP in', 'पुनः कोड भेजें:');
  String get resendOtpButton => _t('Resend OTP Now', 'अभी पुनः ओटीपी भेजें');
  String get otpSentSuccess => _t('Verification code sent successfully.', 'सत्यापन कोड सफलतापूर्वक भेजा गया।');
  String get invalidOtpError => _t('Incorrect OTP entered. Please check and try again.', 'अमान्य ओटीपी दर्ज किया गया। कृपया जांचकर पुनः प्रयास करें।');
  String get expiredOtpError => _t('OTP has expired. Please tap Resend OTP to get a new code.', 'ओटीपी समाप्त हो गया है। नया कोड प्राप्त करने के लिए पुनः प्रयास करें।');
  String get invalidMobileError => _t('Please enter a valid 10-digit mobile number', 'कृपया मान्य 10 अंकों का मोबाइल नंबर दर्ज करें');
  String get nameRequiredError => _t('Please enter your name', 'कृपया अपना नाम दर्ज करें');
  String get continueAsGuest => _t('Continue as Guest (Demo Mode)', 'अतिथि के रूप में जारी रखें (डेमो मोड)');

  // Home Screen: Simple & Farmer-Friendly
  String get greetingFarmer => _t('Namaste', 'नमस्ते');
  String get homeSubtitle => _t('Make informed crop selling decisions today', 'आज ही समझदारी से अपनी फसल बेचने का सही निर्णय लें');
  String get analyzeYourCropButton => _t('ANALYZE YOUR CROP', 'अपनी फसल का विश्लेषण करें');
  String get startAnalysisPrompt => _t(
        'Get market price prediction, spoilage risk, and actionable selling advice in one unified step.',
        'एक ही आसान फॉर्म में बाजार भाव, खराब होने का जोखिम और सटीक बिक्री सलाह प्राप्त करें।',
      );

  // Section: "WHAT SANCHARYA PROVIDES"
  String get whatSancharyaProvidesTitle => _t('WHAT SANCHARYA PROVIDES', 'संचर्या क्या प्रदान करता है');
  String get whatSancharyaProvidesSubtitle => _t(
        'Essential agricultural decision support designed specifically for farmers.',
        'विशेष रूप से किसान भाइयों के लिए तैयार की गई आवश्यक निर्णय सहायता।',
      );

  // 4 Informational Cards
  String get cardCropPriceTitle => _t('Crop Price Estimates', 'फसल भाव अनुमान');
  String get cardCropPriceDesc => _t(
        'Understand estimated selling prices and regional mandi benchmark trends before going to market.',
        'मंडी जाने से पहले अपनी फसल के अनुमानित बिक्री भाव और बाज़ार रुझान को आसानी से समझें।',
      );

  String get cardSpoilageRiskTitle => _t('Spoilage Risk Assessment', 'खराब होने का जोखिम');
  String get cardSpoilageRiskDesc => _t(
        'Assess post-harvest deterioration risks and calculate remaining safe days based on harvest condition.',
        'कटाई के बाद फसल के खराब होने के खतरे और सुरक्षित भंडारण दिनों की सटीक जानकारी पाएं।',
      );

  String get cardNearbyResourcesTitle => _t('Nearby Storage & Mandis', 'नजदीकी शीतगृह व मंडियां');
  String get cardNearbyResourcesDesc => _t(
        'Discover relevant markets, accredited cold-storage facilities, and warehouses near your farm location.',
        'अपने खेत या क्षेत्र के आसपास उपलब्ध कोल्ड स्टोरेज, गोदाम और कृषि उपज मंडियों की खोज करें।',
      );

  String get cardSmartAdviceTitle => _t('Smart Selling Advice', 'सटीक बिक्री सलाह');
  String get cardSmartAdviceDesc => _t(
        'Receive clear, practical recommendations: whether to sell immediately or store for higher future profit.',
        'स्पष्ट और व्यावहारिक सलाह प्राप्त करें: अभी बेचना सही रहेगा या सुरक्षित रखकर भविष्य में लाभ कमाना।',
      );

  String get recentAnalysesTitle => _t('Recent Crop Decisions', 'हालिया फसल निर्णय');
  String get noRecentAnalyses => _t('No analyses yet. Tap "ANALYZE YOUR CROP" to begin.', 'अभी कोई विश्लेषण नहीं है। शुरू करने के लिए "अपनी फसल का विश्लेषण करें" दबाएं।');

  // Single Unified Crop-Analysis Form
  String get unifiedFormTitle => _t('Analyze Your Crop', 'अपनी फसल का विश्लेषण करें');
  String get unifiedFormSubtitle => _t(
        'Enter your harvest details once to receive price prediction, spoilage risk, nearby storage, and smart advice.',
        'एक बार फसल का विवरण दर्ज करें और भाव अनुमान, खराबी का जोखिम, नजदीकी भंडारण व सलाह एक साथ पाएं।',
      );
  String get selectCropLabel => _t('1. Crop Type', '१. फसल का प्रकार');
  String get selectCropHint => _t('Select harvested crop', 'कटी हुई फसल चुनें');
  
  String get locationLabel => _t('2. Farm Location / District', '२. खेत का स्थान / जिला');
  String get locationHint => _t('e.g. Nashik, Lasalgaon, Pune, Indore', 'उदा. नासिक, लासलगांव, पुणे, इंदौर');
  String get useCurrentLocation => _t('Auto-Detect Location', 'वर्तमान स्थान चुनें');

  String get quantityLabel => _t('3. Harvest Quantity', '३. फसल की मात्रा');
  String get quantityHint => _t('e.g. 50', 'उदा. 50');
  String get unitQuintal => _t('Quintals (क्विंटल)', 'क्विंटल (Quintals)');
  String get unitKg => _t('Kilograms (किलो)', 'किलोग्राम (kg)');

  String get harvestDateLabel => _t('4. Harvest Date', '४. कटाई की तारीख');
  String get selectHarvestDate => _t('Select Date', 'तारीख चुनें');
  String get futureDateError => _t('Harvest date cannot be in the future', 'कटाई की तारीख भविष्य की नहीं हो सकती');

  String get cropConditionLabel => _t('5. Visual Crop Condition', '५. फसल की वर्तमान स्थिति');
  String get conditionGood => _t('Good (Fresh & Firm)', 'उत्तम (ताजा और स्वस्थ)');
  String get conditionAverage => _t('Average (Slight Softening)', 'सामान्य (हल्की मुरझाई)');
  String get conditionPoor => _t('Poor (Visible Deterioration)', 'कमजोर (खराब होने के लक्षण)');

  String get generateDecisionReportButton => _t('GENERATE DECISION REPORT', 'निर्णय रिपोर्ट तैयार करें');
  String get analyzingProgressText => _t(
        'Evaluating price trends, spoilage vectors, and nearby resources...',
        'भाव के रुझान, खराबी के जोखिम और नजदीकी संसाधनों का विश्लेषण हो रहा है...',
      );

  // Combined Results Screen
  String get combinedResultsTitle => _t('Crop Decision Report', 'फसल निर्णय रिपोर्ट');
  String get pricePredictionSection => _t('Crop Price Prediction', 'फसल भाव पूर्वानुमान');
  String get currentMarketPrice => _t('Current Mandi Average', 'वर्तमान मंडी औसत');
  String get predictedFuturePrice => _t('Predicted Future Price', 'भविष्य का अनुमानित भाव');
  String get estimatedPriceRange => _t('Estimated Price Range', 'अनुमानित भाव दायरा');
  String get pricePerQuintalUnit => _t('₹ / Quintal', '₹ / क्विंटल');

  String get spoilageRiskSection => _t('Spoilage Risk Analysis', 'फसल खराब होने का जोखिम');
  String get riskLow => _t('Low Risk', 'कम जोखिम');
  String get riskMedium => _t('Moderate Risk', 'मध्यम जोखिम');
  String get riskHigh => _t('High Spoilage Risk', 'अत्यधिक खराब होने का खतरा');
  String get safeDaysRemaining => _t('Safe Shelf Life Remaining', 'सुरक्षित भंडारण समय');
  String get daysUnit => _t('Days', 'दिन');
  String get quintalUnit => _t('Quintals', 'क्विंटल');

  String get nearbyResourcesSection => _t('Discovered Nearby Resources', 'सुझाए गए नजदीकी कृषि संसाधन');
  String get nearbyResourcesDesc => _t(
        'Nearby cold storage and mandi facilities discovered for your location:',
        'आपके दर्ज स्थान के आधार पर नजदीकी कोल्ड स्टोरेज व मंडियां:',
      );

  String get smartRecommendationSection => _t('Smart Recommendation', 'सटीक किसान सलाह');
  String get actionableSteps => _t('Recommended Action Steps', 'महत्वपूर्ण अगले कदम');

  // Voice Text-to-Speech (TTS)
  String get listenReportVoice => _t('Listen to Report (Voice)', 'रिपोर्ट सुनें (आवाज़)');
  String get stopVoice => _t('Stop Voice', 'आवाज़ रोकें');
  String get voiceSpeaking => _t('Reading decision report out loud...', 'रिपोर्ट पढ़कर सुनाई जा रही है...');

  // Resources Screen
  String get resourcesScreenTitle => _t('Agricultural Resources', 'कृषि संसाधन व शीतगृह');
  String get filterAll => _t('All', 'सभी');
  String get filterColdStorage => _t('Cold Storage', 'शीतगृह');
  String get filterWarehouse => _t('Warehouse', 'गोदाम');
  String get filterMandi => _t('Mandi', 'मंडी');
  String get capacityAvailable => _t('Available Capacity', 'उपलब्ध क्षमता');
  String get metricTons => _t('MT', 'मीट्रिक टन');
  String get ratePerDay => _t('Est. Rate', 'अनुमानित दर');
  String get callFacility => _t('Call Facility', 'संपर्क करें');
  String get noResourcesFound => _t('No facilities found for selected filter.', 'चयनित श्रेणी में कोई सुविधा नहीं मिली।');

  // Settings / Profile Screen
  String get settingsTitle => _t('Profile & Settings', 'प्रोफ़ाइल व सेटिंग्स');
  String get languageSetting => _t('App Language', 'ऐप की भाषा');
  String get profileSection => _t('Farmer Profile', 'किसान प्रोफ़ाइल');
  String get registeredPhone => _t('Registered Mobile', 'पंजीकृत मोबाइल');
  String get locationSetting => _t('Base District', 'मुख्य जिला');
  String get aboutSection => _t('About SANCHARYA', 'संचर्या के बारे में');
  String get versionLabel => _t('Version', 'संस्करण');
  String get simulatedDataDisclaimerTitle => _t('Data Architecture Notice', 'डेटा आर्किटेक्चर सूचना');
  String get logoutButton => _t('Switch Profile / Log Out', 'प्रोफ़ाइल बदलें / लॉग आउट');

  // Common UI States
  String get loading => _t('Loading...', 'लोड हो रहा है...');
  String get pleaseWait => _t('Please wait...', 'कृपया प्रतीक्षा करें...');
  String get errorOccurred => _t('An error occurred', 'एक त्रुटि हुई');
  String get retry => _t('Retry', 'पुनः प्रयास करें');
  String get noDataAvailable => _t('No data available', 'कोई डेटा उपलब्ध नहीं');

  // Crop Names
  String get cropTomato => _t('Tomato', 'टमाटर');
  String get cropOnion => _t('Onion', 'प्याज');
  String get cropPotato => _t('Potato', 'आलू');
  String get cropCauliflower => _t('Cauliflower', 'फूलगोभी');
  String get cropWheat => _t('Wheat', 'गेहूं');
  String get cropPaddy => _t('Paddy (Rice)', 'धान (चावल)');
  String get cropSoybean => _t('Soybean', 'सोयाबीन');
  String get cropCotton => _t('Cotton', 'कपास');
  String get cropMustard => _t('Mustard', 'सरसों');
  String get cropChilli => _t('Green Chilli', 'हरी मिर्च');

  // Cold Storage & Mandi Watch
  String get coldStorageTitle => _t('Cold Storage Directory', 'कोल्ड स्टोरेज सूची');
  String get mandiWatchTitle => _t('Mandi Market Rates', 'मंडी बाज़ार भाव');
  String get mandiWatchSubtitle => _t('Daily market price trends for major agricultural produce', 'प्रमुख कृषि उपजों के दैनिक मंडी भाव');
  String get minPrice => _t('Min Price', 'न्यूनतम भाव');
  String get modalPrice => _t('Modal Price', 'मॉडल भाव');
  String get maxPrice => _t('Max Price', 'अधिकतम भाव');

  // NGO & Donation Support Section
  String get ngoTitle => _t('NGO Donation Support', 'एनजीओ व दान सहायता');
  String get ngoSubtitle => _t(
        'Connect with verified relief trusts accepting surplus farm produce',
        'अधिशेष कृषि उपज स्वीकारने वाले सत्यापित सहायता ट्रस्टों से संपर्क करें',
      );
  String get ngoDonateSurplus => _t('Donate Surplus Harvest', 'अधिशेष उपज दान करें');
  String get ngoSearchHint => _t('Search NGOs or locations', 'संस्था या स्थान से खोजें');
  String get ngoSelectCropToDonate => _t('Crop to Donate', 'दान की जाने वाली फसल');
  String get ngoAllCrops => _t('All Crops', 'सभी फसलें');
  String get ngoPickupAvailableOnly => _t('Pickup Available Only', 'केवल पिकअप सुविधा वाले');
  String get ngoCallNow => _t('Call NGO', 'एनजीओ को कॉल करें');
  String get ngoNumberNotAvailable => _t('No mobile number available', 'मोबाइल नंबर उपलब्ध नहीं है');
  String get ngoDemandLevel => _t('Demand Level', 'मांग स्तर');
  String get ngoAcceptedProduce => _t('Accepted Produce', 'स्वीकार्य फसलें');
  String get ngoOperatingHours => _t('Operating Hours', 'कार्य समय');
  String get ngoVerified => _t('Verified NGO Darpan', 'सत्यापित एनजीओ दर्पण');
  String get ngoNoResultsTitle => _t('No matching NGOs found', 'कोई उपयुक्त एनजीओ नहीं मिला');
  String get ngoNoResultsSubtitle => _t(
        'No verified organizations found for the selected location or crop. Try clearing filters or selecting another district.',
        'चयनित स्थान या फसल के लिए कोई सत्यापित संस्था नहीं मिली। कृपया फ़िल्टर हटाएं या अन्य जिला चुनें।',
      );
  String get ngoAlternativeAdvice => _t(
        'Farmers with surplus produce can also contact their regional Krishi Vigyan Kendra (KVK) for relief aggregation.',
        'अधिशेष उपज वाले किसान सहायता संग्रहण के लिए अपने क्षेत्रीय कृषि विज्ञान केंद्र (KVK) से भी संपर्क कर सकते हैं।',
      );
  String get ngoImpactNote => _t('Community Impact', 'सामुदायिक प्रभाव');
  String get ngoLastVerified => _t('Last Verified', 'अंतिम सत्यापन');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
