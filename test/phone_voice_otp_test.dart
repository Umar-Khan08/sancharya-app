import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/core/location/app_location_provider.dart';
import 'package:sancharya/data/interfaces/i_auth_service.dart';
import 'package:sancharya/models/farmer_user.dart';
import 'package:sancharya/models/agri_resource.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/services/phone/phone_call_service.dart';
import 'package:sancharya/services/voice/speech_recognition_service.dart';
import 'package:sancharya/widgets/voice_input_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Phone Call Validation & Normalization Tests', () {
    test('Normalizes standard 10-digit Indian numbers with +91', () {
      expect(PhoneCallService.normalizePhoneNumber('9876543210'), '+919876543210');
      expect(PhoneCallService.normalizePhoneNumber('09876543210'), '+919876543210');
      expect(PhoneCallService.normalizePhoneNumber('+91 98765-43210'), '+919876543210');
      expect(PhoneCallService.normalizePhoneNumber('919876543210'), '+919876543210');
    });

    test('Rejects invalid numbers or fake formats', () {
      expect(PhoneCallService.normalizePhoneNumber(''), isNull);
      expect(PhoneCallService.normalizePhoneNumber('12345'), isNull); // Too short
      expect(PhoneCallService.normalizePhoneNumber('0000000000'), isNull); // Invalid starting digit
      expect(PhoneCallService.normalizePhoneNumber('1234567890'), isNull); // Must start with 6-9 in India
      expect(PhoneCallService.normalizePhoneNumber('abcde'), isNull);
      expect(PhoneCallService.isValidPhoneNumber('9876543210'), isTrue);
      expect(PhoneCallService.isValidPhoneNumber('5555555555'), isFalse);
    });

    test('Formats normalized numbers cleanly for UI display', () {
      expect(PhoneCallService.formatForDisplay('+919876543210'), '+91 98765 43210');
      expect(PhoneCallService.formatForDisplay('9876543210'), '+91 98765 43210');
    });

    test('AgriResource correctly detects missing vs valid phone numbers', () {
      const mandiWithPhone = AgriResource(
        id: 'm1',
        nameEn: 'Azadpur Mandi',
        nameHi: 'आजादपुर मंडी',
        type: AgriResourceType.mandi,
        districtEn: 'Delhi',
        districtHi: 'दिल्ली',
        distanceKm: 5.0,
        capacityMetricTons: 10000,
        availableMetricTons: 3000,
        contactPhone: '+919876543210',
        estimatedRatePerMonthPerQuintal: 45.0,
        isPhoneVerified: true,
      );
      expect(mandiWithPhone.hasValidPhone, isTrue);

      const mandiWithoutPhone = AgriResource(
        id: 'm2',
        nameEn: 'Rural Haat',
        nameHi: 'ग्रामीण हाट',
        type: AgriResourceType.mandi,
        districtEn: 'Delhi',
        districtHi: 'दिल्ली',
        distanceKm: 12.0,
        capacityMetricTons: 500,
        availableMetricTons: 100,
        contactPhone: '',
        estimatedRatePerMonthPerQuintal: 30.0,
      );
      expect(mandiWithoutPhone.hasValidPhone, isFalse);
    });
  });

  group('Farmer OTP Verification & User Model Tests', () {
    test('OtpSession correctly tracks expiration and provider status', () {
      final now = DateTime.now();
      final session = OtpSession(
        verificationId: 'v123456',
        phoneNumber: '+919876543210',
        expiresAt: now.add(const Duration(minutes: 5)),
        isSmsDelivered: true,
        isProviderConfigured: true,
        providerName: 'Fast2SMS',
        cooldownSeconds: 60,
      );

      expect(session.isExpired, isFalse);
      expect(session.providerName, 'Fast2SMS');
      expect(session.isProviderConfigured, isTrue);
      expect(session.isSmsDelivered, isTrue);

      // Expired session
      final expiredSession = OtpSession(
        verificationId: 'v123456',
        phoneNumber: '+919876543210',
        expiresAt: now.subtract(const Duration(seconds: 1)),
        isSmsDelivered: false,
        isProviderConfigured: false,
        providerName: 'unconfigured',
        cooldownSeconds: 60,
      );
      expect(expiredSession.isExpired, isTrue);
      expect(expiredSession.isProviderConfigured, isFalse);
    });

    test('FarmerUser records phone verification timestamp and state', () {
      const unverified = FarmerUser(
        id: 'u1',
        name: 'Ramesh Patel',
        phone: '+919876543210',
        district: 'Indore',
        state: 'Madhya Pradesh',
        isPhoneVerified: false,
      );
      expect(unverified.isPhoneVerified, isFalse);
      expect(unverified.verifiedAt, isNull);

      final verifiedAt = DateTime.now();
      final verified = FarmerUser(
        id: 'u1',
        name: 'Ramesh Patel',
        phone: '+919876543210',
        district: 'Indore',
        state: 'Madhya Pradesh',
        isPhoneVerified: true,
        verifiedAt: verifiedAt,
      );
      expect(verified.isPhoneVerified, isTrue);
      expect(verified.verifiedAt, equals(verifiedAt));
    });
  });

  group('Voice Input Spoken Number Normalization Tests', () {
    test('VoiceInputButton converts spoken Hindi numbers to digits', () {
      expect(VoiceInputButton.convertSpokenNumberToDigits('पचास'), '50');
      expect(VoiceInputButton.convertSpokenNumberToDigits('सौ'), '100');
      expect(VoiceInputButton.convertSpokenNumberToDigits('दस क्विंटल'), '10');
      expect(VoiceInputButton.convertSpokenNumberToDigits('दो सौ'), '200');
      expect(VoiceInputButton.convertSpokenNumberToDigits('एक हजार'), '1000');
    });

    test('VoiceInputButton converts spoken English numbers to digits', () {
      expect(VoiceInputButton.convertSpokenNumberToDigits('fifty'), '50');
      expect(VoiceInputButton.convertSpokenNumberToDigits('twenty five'), '25');
      expect(VoiceInputButton.convertSpokenNumberToDigits('one hundred and fifty'), '150');
      expect(VoiceInputButton.convertSpokenNumberToDigits('120 quintals'), '120');
    });
  });

  group('Mandi Price Provenance & Nearest-Market Fallback Tests', () {
    test('MarketPriceBenchmark distinguishes District Live, Nearby Mandi Fallback, and Demonstration Data', () {
      const liveMandi = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2400.0,
        predictedFuturePricePerQuintal: 2480.0,
        minExpectedPrice: 2300.0,
        maxExpectedPrice: 2500.0,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 3.3,
        mandiName: 'Azadpur',
        isLiveMandiData: true,
        fallbackLevel: 'district',
        arrivalDate: '2026-10-25',
      );
      expect(liveMandi.isDistrictLive, isTrue);
      expect(liveMandi.isNearbyMandi, isFalse);
      expect(liveMandi.isDemonstration, isFalse);

      const nearbyMandi = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2350.0,
        predictedFuturePricePerQuintal: 2420.0,
        minExpectedPrice: 2280.0,
        maxExpectedPrice: 2450.0,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 2.9,
        mandiName: 'Najafgarh',
        isLiveMandiData: true,
        fallbackLevel: 'nearby_mandi',
        distanceKm: 18.4,
        arrivalDate: '2026-10-25',
        noticeMessageEn: 'Nearby Mandi Reference Price (18.4 km away)',
        noticeMessageHi: 'निकटतम मंडी संदर्भ भाव (18.4 किमी दूर)',
      );
      expect(nearbyMandi.isDistrictLive, isFalse);
      expect(nearbyMandi.isNearbyMandi, isTrue);
      expect(nearbyMandi.isDemonstration, isFalse);
      expect(nearbyMandi.distanceKm, 18.4);
      expect(nearbyMandi.noticeMessage(false), 'Nearby Mandi Reference Price (18.4 km away)');
      expect(nearbyMandi.noticeMessage(true), contains('निकटतम मंडी संदर्भ भाव'));

      const demoMandi = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2100.0,
        predictedFuturePricePerQuintal: 2150.0,
        minExpectedPrice: 2000.0,
        maxExpectedPrice: 2200.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Local Market',
        isLiveMandiData: false,
        fallbackLevel: 'demonstration',
      );
      expect(demoMandi.isDemonstration, isTrue);
      expect(demoMandi.isDistrictLive, isFalse);
      expect(demoMandi.isNearbyMandi, isFalse);
    });

    test('Never silently disguises nearby fallback price as local market price', () {
      const nearbyMandi = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2200.0,
        predictedFuturePricePerQuintal: 2250.0,
        minExpectedPrice: 2100.0,
        maxExpectedPrice: 2300.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 2.2,
        mandiName: 'Karnal Market',
        isLiveMandiData: true,
        fallbackLevel: 'nearby_mandi',
        distanceKm: 42.1,
        arrivalDate: '2026-10-24',
      );

      // Must explicitly declare distance and fallbackLevel
      expect(nearbyMandi.isNearbyMandi, isTrue);
      expect(nearbyMandi.distanceKm, 42.1);
      expect(nearbyMandi.isDistrictLive, isFalse);
    });

    test('Holdout Price Forecast correctly stores evaluation metrics and horizon', () {
      const forecastMandi = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2400.0,
        predictedFuturePricePerQuintal: 2580.0,
        minExpectedPrice: 2300.0,
        maxExpectedPrice: 2650.0,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 7.5,
        mandiName: 'Indore Mandi',
        isLiveMandiData: true,
        isPredictionModelConnected: true,
        forecastModelName: 'Holt\'s Double Exponential Smoothing (80/20 Chronological Split)',
        holdoutMape: 3.42,
        forecastHorizonDays: 30,
        forecastPeriod: 'Past 30 Days Observations',
      );

      expect(forecastMandi.isPredictionModelConnected, isTrue);
      expect(forecastMandi.forecastModelName, contains('Holt\'s Double Exponential Smoothing'));
      expect(forecastMandi.holdoutMape, 3.42);
      expect(forecastMandi.forecastHorizonDays, 30);
    });

    test('Demonstration Price Forecast is never disguised as verified historical model', () {
      const demoForecast = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2100.0,
        predictedFuturePricePerQuintal: 2180.0,
        minExpectedPrice: 2000.0,
        maxExpectedPrice: 2300.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 3.8,
        mandiName: 'Regional APMC',
        isLiveMandiData: false,
        isPredictionModelConnected: false,
        fallbackLevel: 'demonstration',
        forecastModelName: 'Demonstration Holt\'s Smoothing',
        holdoutMape: null,
      );

      expect(demoForecast.isDemonstration, isTrue);
      expect(demoForecast.isDistrictLive, isFalse);
      expect(demoForecast.isPredictionModelConnected, isFalse);
      expect(demoForecast.forecastModelName, contains('Demonstration'));
    });
  });

  group('Location State & Anti-Silent Default Tests', () {
    test('AppLocationProvider distinguishes unchosen initial state from user-selected location', () async {
      final provider = AppLocationProvider();
      expect(provider.hasUserLocation, isFalse);
      expect(provider.isAutoDetected, isFalse);

      // After user explicitly sets a location
      await provider.setManualLocation('Indore, Madhya Pradesh', isHindi: false);
      expect(provider.hasUserLocation, isTrue);
    });

    test('Stale request epoch guard prevents race condition from overwriting recent manual entry', () async {
      final provider = AppLocationProvider();
      final epoch1 = provider.requestEpoch;

      await provider.setManualLocation('Kanpur, Uttar Pradesh', isHindi: false);
      final epoch2 = provider.requestEpoch;

      expect(epoch2, greaterThan(epoch1));
      expect(provider.hasUserLocation, isTrue);
    });

    test('Kanpur Nagar and Agra resolve to correct respective coordinates', () async {
      final provider = AppLocationProvider();

      await provider.setManualLocation('Kanpur Nagar, Uttar Pradesh', isHindi: false);
      expect(provider.latitude, closeTo(26.4499, 0.01));
      expect(provider.longitude, closeTo(80.3319, 0.01));
      expect(provider.district, 'Kanpur Nagar');

      await provider.setManualLocation('Agra, Uttar Pradesh', isHindi: false);
      expect(provider.latitude, closeTo(27.1767, 0.01));
      expect(provider.longitude, closeTo(78.0081, 0.01));
      expect(provider.district, 'Agra');
    });

    test('Prevention of stale coordinates overwriting manual selection when resolution fails', () async {
      final provider = AppLocationProvider();

      // First set Agra
      await provider.setManualLocation('Agra, Uttar Pradesh', isHindi: false);
      expect(provider.latitude, closeTo(27.1767, 0.01));

      // Now set unknown district where resolution fails
      await provider.setManualLocation('UnresolvableUnknownDistrict123', isHindi: false);
      // Coordinates MUST be null, NOT lingering from Agra!
      expect(provider.latitude, isNull);
      expect(provider.longitude, isNull);
      expect(provider.hasValidCoordinates, isFalse);
    });
  });

  group('Speech Recognition Service & Bilingual Voice Handling Tests', () {
    test('Default language and locale id mapping', () {
      final service = SpeechRecognitionService();
      service.setLanguage(VoiceLanguage.hindi);
      expect(service.selectedLanguage, VoiceLanguage.hindi);
      expect(service.currentLocaleId, 'hi_IN');

      service.setLanguage(VoiceLanguage.english);
      expect(service.selectedLanguage, VoiceLanguage.english);
      expect(service.currentLocaleId, 'en_IN');
    });

    test('Bilingual service unavailable error message when engine is unconfigured or unavailable', () {
      final service = SpeechRecognitionService();
      service.setErrorMessageForTest(
        en: 'Speech recognition service is not available on this device/emulator. Please enter text manually using the keyboard.',
        hi: 'इस डिवाइस या एमुलेटर पर वाक् पहचान (स्पीच) सेवा उपलब्ध नहीं है। कृपया कीबोर्ड से टाइप करें।',
      );

      expect(service.errorMessageEn, contains('not available on this device/emulator'));
      expect(service.errorMessageEn, contains('enter text manually'));
      expect(service.errorMessageHi, contains('वाक् पहचान (स्पीच) सेवा उपलब्ध नहीं है'));
      expect(service.errorMessageHi, contains('कीबोर्ड से टाइप करें'));
    });

    test('Bilingual microphone permission denied error message', () {
      final service = SpeechRecognitionService();
      service.setErrorMessageForTest(
        en: 'Microphone permission was denied. Please allow microphone access in device settings.',
        hi: 'माइक्रोफ़ोन अनुमति अस्वीकृत की गई। कृपया सेटिंग्स में जाकर अनुमति दें।',
      );

      expect(service.errorMessageEn, contains('Microphone permission was denied'));
      expect(service.errorMessageHi, contains('माइक्रोफ़ोन अनुमति अस्वीकृत'));
    });

    test('Bilingual speech timeout and silence notification', () {
      final service = SpeechRecognitionService();
      service.setErrorMessageForTest(
        en: 'No speech detected (timeout). Please tap the microphone and speak again.',
        hi: 'कोई आवाज़ नहीं सुनाई दी (समय समाप्त)। कृपया माइक दबाकर पुनः बोलें।',
      );

      expect(service.errorMessageEn, contains('timeout'));
      expect(service.errorMessageHi, contains('समय समाप्त'));
    });
  });
}
