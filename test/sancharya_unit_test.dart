import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/data/demo_data/demo_crops.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/data/resolvers/crop_resolver.dart';
import 'package:sancharya/services/agriculture/demo_agriculture_service.dart';
import 'package:sancharya/services/auth/demo_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SANCHARYA Auth Unit Tests', () {
    late DemoAuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = DemoAuthService();
    });

    test('Entering phone number does NOT automatically log in user', () async {
      final user = await authService.getCurrentUser();
      expect(user, isNull);
    });

    test('requestOtp creates a 6-digit OTP session without logging in', () async {
      final session = await authService.requestOtp('9876543210');
      expect(session.testCodeForDisplay != null, true);
      expect(session.testCodeForDisplay!.length, 6);
      expect(int.tryParse(session.testCodeForDisplay!), isNotNull);
      expect(session.isExpired, false);

      // User must still NOT be logged in
      final currentUser = await authService.getCurrentUser();
      expect(currentUser, isNull);
    });

    test('verifyOtp rejects invalid OTP code', () async {
      final session = await authService.requestOtp('9876543210');
      expect(
        () async => await authService.verifyOtp(
          verificationId: session.verificationId,
          otp: '000000',
          name: 'Test Farmer',
          district: 'Nashik',
        ),
        throwsA(isA<Exception>()),
      );

      final user = await authService.getCurrentUser();
      expect(user, isNull);
    });

    test('verifyOtp accepts correct OTP and logs in user', () async {
      final session = await authService.requestOtp('9876543210');
      final validOtp = session.testCodeForDisplay!;

      final loggedInUser = await authService.verifyOtp(
        verificationId: session.verificationId,
        otp: validOtp,
        name: 'Ramesh Patel',
        district: 'Nashik',
      );

      expect(loggedInUser.phone, '9876543210');
      expect(loggedInUser.name, 'Ramesh Patel');

      final currentUser = await authService.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.phone, '9876543210');

      // Logout clears session
      await authService.logout();
      expect(await authService.getCurrentUser(), isNull);
    });
  });

  group('SANCHARYA Agriculture Service & Unified Input Tests', () {
    late DemoAgricultureService agService;

    setUp(() {
      agService = DemoAgricultureService();
    });

    test('Unified CropAnalysisInput correctly converts quintals and calculates age', () {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Nashik, Maharashtra',
        quantity: 500,
        quantityUnit: QuantityUnit.kilogram,
        harvestDate: DateTime.now().subtract(const Duration(days: 2)),
        condition: CropCondition.good,
      );

      expect(input.quantityInQuintals, 5.0);
      expect(input.daysSinceHarvest, 2);
    });

    test('Analyze Crop returns unified prediction, risk, nearby resources and voice summaries', () async {
      final onionCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'onion');
      final input = CropAnalysisInput(
        crop: onionCrop,
        location: 'Nashik APMC',
        quantity: 10,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      final result = await agService.analyzeCrop(input);

      // Verify all 4 aspects exist in single result
      expect(result.marketBenchmark.isDataNotAvailable, true);
      expect(result.marketBenchmark.currentAvgPricePerQuintal, 0.0);
      expect(result.marketBenchmark.predictedFuturePricePerQuintal, 0.0);
      expect(result.marketBenchmark.noticeMessageEn, 'Data Not Available');
      expect(result.spoilageRisk.riskLevel, SpoilageRiskLevel.low);
      expect(result.recommendation.headlineEn.isNotEmpty, true);
      expect(result.nearbyResources.isNotEmpty, true);
      expect(result.speechSummaryEn.isNotEmpty, true);
      expect(result.speechSummaryHi.isNotEmpty, true);
      expect(result.isSimulatedModel, true);
    });
  });

  group('Algorithm Section 3: Crop Selection and Manual Crop Entry Resolver', () {
    final available = DemoCrops.sampleCrops;

    test('Exact English match resolves canonical crop', () {
      final crop = CropResolver.resolve('Tomato', available);
      expect(crop, isNotNull);
      expect(crop!.nameEn, 'Tomato');
    });

    test('Exact Hindi match resolves canonical crop', () {
      final crop = CropResolver.resolve('टमाटर', available);
      expect(crop, isNotNull);
      expect(crop!.nameEn, 'Tomato');
    });

    test('Hindi transliteration / alias resolves canonical crop', () {
      final tamatar = CropResolver.resolve('tamatar', available);
      expect(tamatar, isNotNull);
      expect(tamatar!.nameEn, 'Tomato');

      final pyaz = CropResolver.resolve('pyaz', available);
      expect(pyaz, isNotNull);
      expect(pyaz!.nameEn, 'Onion');

      final aloo = CropResolver.resolve('  aloo  ', available); // with whitespace
      expect(aloo, isNotNull);
      expect(aloo!.nameEn, 'Potato');
    });

    test('Unsupported or ambiguous crops return null (no silent replacement)', () {
      final unknown = CropResolver.resolve('Dragonfruit123', available);
      expect(unknown, isNull);
    });

    test('Autocomplete suggestions return matching crops', () {
      final suggestions = CropResolver.getSuggestions('to', available);
      expect(suggestions.any((c) => c.nameEn == 'Tomato'), isTrue);
    });
  });

  group('Algorithm Section 8: Quantity and Revenue Calculation', () {
    final crop = DemoCrops.sampleCrops.first;

    test('Calculates gross crop value in quintals correctly', () {
      final input = CropAnalysisInput(
        crop: crop,
        quantity: 50.0,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 2)),
        condition: CropCondition.good,
        location: 'Kanpur',
      );

      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2000.0,
        predictedFuturePricePerQuintal: 2200.0,
        minExpectedPrice: 1900.0,
        maxExpectedPrice: 2300.0,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 10.0,
        mandiName: 'Kanpur Mandi',
        isDatasetRecord: true,
      );

      final result = CombinedCropAnalysisResult(
        analysisId: 'test_gross_quintal',
        timestamp: DateTime.now(),
        input: input,
        spoilageRisk: const SpoilageRiskAssessment(
          riskLevel: SpoilageRiskLevel.low,
          riskScore: 20,
          safeShelfLifeDaysRemaining: 10,
          explanationEn: 'Good',
          explanationHi: 'अच्छा',
          criticalRiskFactorsEn: [],
          criticalRiskFactorsHi: [],
          preservationTipsEn: [],
          preservationTipsHi: [],
        ),
        marketBenchmark: benchmark,
        recommendation: const SellingRecommendation(
          action: SellingAction.holdNormal,
          headlineEn: 'Hold',
          headlineHi: 'रोकें',
          rationaleEn: 'Good rate',
          rationaleHi: 'अच्छा भाव',
          estimatedNetAdvantagePerQuintal: 200,
          nextStepsEn: [],
          nextStepsHi: [],
        ),
        nearbyResources: const [],
      );

      // 50 quintals * 2000 per quintal = 100,000
      expect(result.grossCropValue, 100000.0);
      expect(result.speechSummaryEn, contains('₹100000'));
      expect(result.speechSummaryHi, contains('₹100000'));
    });

    test('Calculates gross crop value in kilograms correctly', () {
      final input = CropAnalysisInput(
        crop: crop,
        quantity: 500.0, // 500 kg = 5 quintals
        quantityUnit: QuantityUnit.kilogram,
        harvestDate: DateTime.now().subtract(const Duration(days: 2)),
        condition: CropCondition.good,
        location: 'Kanpur',
      );

      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2000.0, // 2000/100 = 20/kg
        predictedFuturePricePerQuintal: 2200.0,
        minExpectedPrice: 1900.0,
        maxExpectedPrice: 2300.0,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 10.0,
        mandiName: 'Kanpur Mandi',
        isDatasetRecord: true,
      );

      final result = CombinedCropAnalysisResult(
        analysisId: 'test_gross_kg',
        timestamp: DateTime.now(),
        input: input,
        spoilageRisk: const SpoilageRiskAssessment(
          riskLevel: SpoilageRiskLevel.low,
          riskScore: 20,
          safeShelfLifeDaysRemaining: 10,
          explanationEn: 'Good',
          explanationHi: 'अच्छा',
          criticalRiskFactorsEn: [],
          criticalRiskFactorsHi: [],
          preservationTipsEn: [],
          preservationTipsHi: [],
        ),
        marketBenchmark: benchmark,
        recommendation: const SellingRecommendation(
          action: SellingAction.holdNormal,
          headlineEn: 'Hold',
          headlineHi: 'रोकें',
          rationaleEn: 'Good rate',
          rationaleHi: 'अच्छा भाव',
          estimatedNetAdvantagePerQuintal: 200,
          nextStepsEn: [],
          nextStepsHi: [],
        ),
        nearbyResources: const [],
      );

      // 500 kg * 20.0 per kg = 10,000
      expect(result.grossCropValue, 10000.0);
    });

    test('Returns null grossCropValue when mandi price is unavailable (no fabricated value)', () {
      final input = CropAnalysisInput(
        crop: crop,
        quantity: 50.0,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 2)),
        condition: CropCondition.good,
        location: 'Unknown',
      );

      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 0.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 0.0,
        maxExpectedPrice: 0.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'None',
        isLiveMandiData: false,
        isDatasetRecord: false,
      );

      final result = CombinedCropAnalysisResult(
        analysisId: 'test_no_fabrication',
        timestamp: DateTime.now(),
        input: input,
        spoilageRisk: const SpoilageRiskAssessment(
          riskLevel: SpoilageRiskLevel.low,
          riskScore: 20,
          safeShelfLifeDaysRemaining: 10,
          explanationEn: 'Good',
          explanationHi: 'अच्छा',
          criticalRiskFactorsEn: [],
          criticalRiskFactorsHi: [],
          preservationTipsEn: [],
          preservationTipsHi: [],
        ),
        marketBenchmark: benchmark,
        recommendation: const SellingRecommendation(
          action: SellingAction.holdNormal,
          headlineEn: 'Hold',
          headlineHi: 'रोकें',
          rationaleEn: 'Good',
          rationaleHi: 'अच्छा',
          estimatedNetAdvantagePerQuintal: 0,
          nextStepsEn: [],
          nextStepsHi: [],
        ),
        nearbyResources: const [],
      );

      expect(result.grossCropValue, isNull);
    });
  });
}
