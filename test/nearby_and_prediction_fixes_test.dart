import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancharya/core/localization/app_language_provider.dart';
import 'package:sancharya/models/agri_resource.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/models/crop_model.dart';
import 'package:sancharya/core/location/app_location_provider.dart';
import 'package:sancharya/screens/cold_storage/cold_storage_screen.dart';
import 'package:sancharya/screens/crop_results/crop_results_screen.dart';
import 'package:sancharya/services/agriculture/agmarknet_api_service.dart';
import 'package:sancharya/services/auth/api_auth_service.dart';
import 'package:sancharya/services/history/search_history_service.dart';
import 'package:sancharya/widgets/loading_indicator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleCrop = Crop(
    id: 'crop_tomato',
    nameEn: 'Tomato',
    nameHi: 'टमाटर',
    category: 'Vegetables',
    standardShelfLifeDays: 5,
    benchmarkPricePerQuintal: 2200.0,
  );

  const sampleBenchmark = MarketPriceBenchmark(
    currentAvgPricePerQuintal: 2200.0,
    predictedFuturePricePerQuintal: 2450.0,
    minExpectedPrice: 2000.0,
    maxExpectedPrice: 2600.0,
    trend: PriceTrend.rising,
    expectedPriceChangePercent: 11.4,
    mandiName: 'Pune APMC',
    district: 'Pune',
    state: 'Maharashtra',
    fallbackLevel: 'district',
    requestedDistrict: 'Pune',
    forecastModelName: 'LinearTrendForecaster',
    predictionNoticeEn: 'Model verified against CEDA historical prices with holdout validation.',
    predictionNoticeHi: 'मॉडल का CEDA ऐतिहासिक मूल्यों के साथ सत्यापन किया गया।',
    holdoutMape: 8.5,
    forecastHorizonDays: 14,
  );

  const sampleRisk = SpoilageRiskAssessment(
    riskLevel: SpoilageRiskLevel.low,
    riskScore: 20,
    safeShelfLifeDaysRemaining: 5,
    explanationEn: 'Low ambient spoilage risk',
    explanationHi: 'कम जोखिम',
    criticalRiskFactorsEn: [],
    criticalRiskFactorsHi: [],
    preservationTipsEn: [],
    preservationTipsHi: [],
  );

  const sampleRec = SellingRecommendation(
    action: SellingAction.sellNow,
    headlineEn: 'Sell at nearby APMC within 2 days',
    headlineHi: '2 दिनों में नजदीकी मंडी में बेचें',
    rationaleEn: 'Good current price',
    rationaleHi: 'अच्छा मूल्य',
    estimatedNetAdvantagePerQuintal: 150.0,
    nextStepsEn: [],
    nextStepsHi: [],
  );

  final List<AgriResource> sampleResources = [
    const AgriResource(
      id: 'res_mandi_1',
      nameEn: 'Pune Central Agricultural Mandi',
      nameHi: 'पुणे केंद्रीय कृषि मंडी',
      type: AgriResourceType.mandi,
      distanceKm: 4.8,
      districtEn: 'Pune',
      districtHi: 'पुणे',
      capacityMetricTons: 0.0,
      availableMetricTons: 0.0,
      contactPhone: '020-24261234',
      estimatedRatePerMonthPerQuintal: 0.0,
      latitude: 18.4900,
      longitude: 73.8600,
    ),
    const AgriResource(
      id: 'res_cs_1',
      nameEn: 'Sahyadri Agro Cold Storage',
      nameHi: 'सह्याद्री एग्रो कोल्ड स्टोरेज',
      type: AgriResourceType.coldStorage,
      distanceKm: 12.3,
      districtEn: 'Pune',
      districtHi: 'पुणे',
      capacityMetricTons: 5000.0,
      availableMetricTons: 1200.0,
      contactPhone: '9876543210',
      estimatedRatePerMonthPerQuintal: 60.0,
    ),
  ];

  CombinedCropAnalysisResult createResult({List<AgriResource>? resources}) {
    return CombinedCropAnalysisResult(
      analysisId: 'analysis_regression_1',
      timestamp: DateTime.now(),
      input: CropAnalysisInput(
        crop: sampleCrop,
        location: 'Pune, Maharashtra',
        quantity: 25.0,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
        latitude: 18.5204,
        longitude: 73.8567,
      ),
      spoilageRisk: sampleRisk,
      marketBenchmark: sampleBenchmark,
      recommendation: sampleRec,
      nearbyResources: resources ?? sampleResources,
      isSimulatedModel: false,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Nearby Resources Determinism & History Serialization Tests', () {
    test('SearchHistoryService serializes and restores nearby resources accurately', () async {
      final original = createResult(resources: sampleResources);

      final saved = await SearchHistoryService.saveAnalysis(original);
      expect(saved, isTrue);

      final history = await SearchHistoryService.getRecentAnalyses();
      expect(history.length, 1);

      final restored = history.first;
      expect(restored.nearbyResources.length, 2);

      final r1 = restored.nearbyResources[0];
      expect(r1.id, 'res_mandi_1');
      expect(r1.nameEn, 'Pune Central Agricultural Mandi');
      expect(r1.type, AgriResourceType.mandi);
      expect(r1.distanceKm, 4.8);
      expect(r1.contactPhone, '020-24261234');

      final r2 = restored.nearbyResources[1];
      expect(r2.id, 'res_cs_1');
      expect(r2.nameEn, 'Sahyadri Agro Cold Storage');
      expect(r2.type, AgriResourceType.coldStorage);
      expect(r2.distanceKm, 12.3);
      expect(r2.capacityMetricTons, 5000.0);
      expect(r2.availableMetricTons, 1200.0);
      expect(r2.contactPhone, '9876543210');
    });

    test('SearchHistoryService handles empty nearby resources list gracefully', () async {
      final emptyResourcesResult = createResult(resources: const []);

      final saved = await SearchHistoryService.saveAnalysis(emptyResourcesResult);
      expect(saved, isTrue);

      final history = await SearchHistoryService.getRecentAnalyses();
      expect(history.first.nearbyResources, isEmpty);
    });

    testWidgets('CropResultsScreen displays facility cards directly when nearbyResources are present',
        (tester) async {
      final result = createResult(resources: sampleResources);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
          child: MaterialApp(
            home: CropResultsScreen(result: result),
          ),
        ),
      );
      await tester.pump();

      // Verify that facility names are rendered
      expect(find.text('Pune Central Agricultural Mandi'), findsOneWidget);
      expect(find.text('Sahyadri Agro Cold Storage'), findsOneWidget);

      // Verify no generic explore/empty card or loading indicator is shown
      expect(find.byType(LoadingIndicator), findsNothing);
      expect(
        find.text('No Mapped Agricultural Mandi or Cold-Storage Found in Searched Area'),
        findsNothing,
      );
    });

    testWidgets('CropResultsScreen dynamically discovers nearby facilities when initialized with empty list for Kanpur',
        (tester) async {
      final kanpurResult = CombinedCropAnalysisResult(
        analysisId: 'analysis_kanpur_1',
        timestamp: DateTime.now(),
        input: CropAnalysisInput(
          crop: sampleCrop,
          location: 'Kanpur, Uttar Pradesh',
          quantity: 20.0,
          quantityUnit: QuantityUnit.quintal,
          harvestDate: DateTime.now().subtract(const Duration(days: 1)),
          condition: CropCondition.good,
          latitude: 26.4499,
          longitude: 80.3319,
        ),
        spoilageRisk: sampleRisk,
        marketBenchmark: const MarketPriceBenchmark(
          currentAvgPricePerQuintal: 2100.0,
          predictedFuturePricePerQuintal: 2200.0,
          minExpectedPrice: 1950.0,
          maxExpectedPrice: 2300.0,
          trend: PriceTrend.rising,
          expectedPriceChangePercent: 4.8,
          mandiName: 'Chakarpur Mandi',
          district: 'Kanpur Nagar',
          state: 'Uttar Pradesh',
          fallbackLevel: 'district',
          requestedDistrict: 'Kanpur Nagar',
        ),
        recommendation: sampleRec,
        nearbyResources: const [],
        isSimulatedModel: false,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
          child: MaterialApp(
            home: CropResultsScreen(result: kanpurResult),
          ),
        ),
      );
      // Frame 1: loading scheduled
      await tester.pump();
      // Settle all futures (mandi discovery loads curated physical facilities)
      await tester.pumpAndSettle();

      // Curated physical mandi for Kanpur Nagar must be discovered and displayed
      expect(find.text('Chakarpur Krishi Utpadan Mandi'), findsOneWidget);
      expect(
        find.text('No Mapped Agricultural Mandi or Cold-Storage Found in Searched Area'),
        findsNothing,
      );
    });

    testWidgets('CropResultsScreen displays empty/explore state when no facilities are found in searched area',
        (tester) async {
      final isolatedResult = CombinedCropAnalysisResult(
        analysisId: 'analysis_isolated_1',
        timestamp: DateTime.now(),
        input: CropAnalysisInput(
          crop: sampleCrop,
          location: 'Remote Island, Nowhere',
          quantity: 10.0,
          quantityUnit: QuantityUnit.quintal,
          harvestDate: DateTime.now().subtract(const Duration(days: 1)),
          condition: CropCondition.good,
          latitude: 0.0001,
          longitude: 0.0001,
        ),
        spoilageRisk: sampleRisk,
        marketBenchmark: const MarketPriceBenchmark(
          currentAvgPricePerQuintal: 2000.0,
          predictedFuturePricePerQuintal: 2000.0,
          minExpectedPrice: 1900.0,
          maxExpectedPrice: 2100.0,
          trend: PriceTrend.stable,
          expectedPriceChangePercent: 0.0,
          mandiName: 'Remote Mandi',
          district: 'NonExistentDistrictXYZ',
          fallbackLevel: 'state',
          requestedDistrict: 'NonExistentDistrictXYZ',
        ),
        recommendation: sampleRec,
        nearbyResources: const [],
        isSimulatedModel: false,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
          child: MaterialApp(
            home: CropResultsScreen(result: isolatedResult),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        find.text('No Mapped Agricultural Mandi or Cold-Storage Found in Searched Area'),
        findsOneWidget,
      );
      expect(find.text('Open Cold Storage Finder'), findsOneWidget);
    });

    testWidgets('ColdStorageScreen renders filter chips and loads facilities deterministically',
        (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppLanguageProvider()),
            ChangeNotifierProvider(create: (_) => AppLocationProvider()),
          ],
          child: const MaterialApp(
            home: ColdStorageScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ColdStorageScreen), findsOneWidget);
      // Filter chips must be present
      expect(find.text('Cold Storage'), findsOneWidget);
      expect(find.text('Mandi'), findsOneWidget);
    });
  });

  group('Price Prediction & Benchmark Holdout Integrity Tests', () {
    test('MarketPriceBenchmark preserves separate predictionNotice and holdout metrics', () {
      expect(
        sampleBenchmark.predictionNotice(false),
        'Model verified against CEDA historical prices with holdout validation.',
      );
      expect(
        sampleBenchmark.predictionNotice(true),
        'मॉडल का CEDA ऐतिहासिक मूल्यों के साथ सत्यापन किया गया।',
      );
      expect(sampleBenchmark.holdoutMape, 8.5);
      expect(sampleBenchmark.forecastHorizonDays, 14);
      expect(sampleBenchmark.forecastModelName, 'LinearTrendForecaster');
    });

    test('MarketPriceBenchmark preserves separate predictionNotice without conflating with noticeMessage', () {
      const benchmarkWithoutPredictionNotice = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2000.0,
        predictedFuturePricePerQuintal: 2050.0,
        minExpectedPrice: 1900.0,
        maxExpectedPrice: 2200.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 2.5,
        mandiName: 'Lucknow APMC',
        noticeMessageEn: 'District live mandi price',
        noticeMessageHi: 'जिला लाइव मंडी मूल्य',
      );

      // Prediction notice is null so mandi notice is not conflated with model accuracy
      expect(benchmarkWithoutPredictionNotice.predictionNotice(false), isNull);
      expect(benchmarkWithoutPredictionNotice.predictionNotice(true), isNull);
      expect(benchmarkWithoutPredictionNotice.noticeMessage(false), 'District live mandi price');
      expect(benchmarkWithoutPredictionNotice.noticeMessage(true), 'जिला लाइव मंडी मूल्य');
    });

    test('Backend services default to production Render URL when BACKEND_URL define is omitted', () {
      expect(
        AgmarknetAgricultureService.defaultProductionBackendUrl,
        'https://sancharya-backend.onrender.com',
      );
      expect(
        ApiAuthService.defaultProductionBackendUrl,
        'https://sancharya-backend.onrender.com',
      );
    });

    test('Historical and offline dataset records are never labeled as current/today prices in TTS narration', () {
      const tomatoCrop = Crop(
        id: 'crop_tomato',
        nameEn: 'Tomato',
        nameHi: 'टमाटर',
        category: 'Vegetables',
        standardShelfLifeDays: 5,
        benchmarkPricePerQuintal: 1991.0,
      );

      const staleBenchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 1991.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 1800.0,
        maxExpectedPrice: 2100.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'APMC Krishi Upaj Mandi Yard, Chandwad',
        market: 'APMC Krishi Upaj Mandi Yard, Chandwad',
        district: 'Nashik',
        state: 'Maharashtra',
        arrivalDate: '2026-10-24',
        fallbackLevel: 'district',
        requestedDistrict: 'Nashik',
        isLiveMandiData: false,
        isDatasetRecord: true,
      );

      final analysis = CombinedCropAnalysisResult(
        analysisId: 'test_nashik_stale_1',
        timestamp: DateTime.now(),
        input: CropAnalysisInput(
          crop: tomatoCrop,
          location: 'Chandwad, Nashik, Maharashtra',
          quantity: 20.0,
          quantityUnit: QuantityUnit.quintal,
          harvestDate: DateTime.now().subtract(const Duration(days: 1)),
          condition: CropCondition.good,
        ),
        spoilageRisk: sampleRisk,
        marketBenchmark: staleBenchmark,
        recommendation: sampleRec,
        nearbyResources: const [],
        isSimulatedModel: false,
      );

      // Verify English narration does NOT claim 1991 is "Current market price"
      expect(analysis.speechSummaryEn, isNot(contains('Current market price is ₹1991')));
      expect(analysis.speechSummaryEn, contains('Recorded market observation on 2026-10-24 at APMC Krishi Upaj Mandi Yard, Chandwad was ₹1991 per quintal'));

      // Verify Hindi narration does NOT claim 1991 is "वर्तमान मंडी भाव"
      expect(analysis.speechSummaryHi, isNot(contains('वर्तमान मंडी भाव लगभग ₹1991')));
      expect(analysis.speechSummaryHi, contains('दर्ज पिछला मंडी रिकॉर्ड (2026-10-24) APMC Krishi Upaj Mandi Yard, Chandwad पर लगभग ₹1991 प्रति क्विंटल था'));
    });

    testWidgets('CropResultsScreen displays recorded observation date and does not label stale 1991 as Current Mandi Price',
        (tester) async {
      const tomatoCrop = Crop(
        id: 'crop_tomato',
        nameEn: 'Tomato',
        nameHi: 'टमाटर',
        category: 'Vegetables',
        standardShelfLifeDays: 5,
        benchmarkPricePerQuintal: 1991.0,
      );

      const staleBenchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 1991.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 1800.0,
        maxExpectedPrice: 2100.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'APMC Krishi Upaj Mandi Yard, Chandwad',
        market: 'APMC Krishi Upaj Mandi Yard, Chandwad',
        district: 'Nashik',
        state: 'Maharashtra',
        arrivalDate: '2026-10-24',
        fallbackLevel: 'district',
        requestedDistrict: 'Nashik',
        isLiveMandiData: false,
        isDatasetRecord: true,
      );

      final analysis = CombinedCropAnalysisResult(
        analysisId: 'test_ui_nashik_stale_1',
        timestamp: DateTime.now(),
        input: CropAnalysisInput(
          crop: tomatoCrop,
          location: 'Chandwad, Nashik, Maharashtra',
          quantity: 20.0,
          quantityUnit: QuantityUnit.quintal,
          harvestDate: DateTime.now().subtract(const Duration(days: 1)),
          condition: CropCondition.good,
        ),
        spoilageRisk: sampleRisk,
        marketBenchmark: staleBenchmark,
        recommendation: sampleRec,
        nearbyResources: sampleResources,
        isSimulatedModel: false,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppLanguageProvider(),
          child: MaterialApp(
            home: CropResultsScreen(result: analysis),
          ),
        ),
      );
      await tester.pump();

      // Price must be displayed
      expect(find.textContaining('1991'), findsWidgets);
      expect(find.text('₹ 19.9 / kg'), findsOneWidget);

      // Must NOT be labeled as "Current Mandi Price"
      expect(find.text('Current Mandi Price'), findsNothing);

      // MUST be labeled as "Recorded Rate (2026-10-24)"
      expect(find.text('Recorded Rate (2026-10-24)'), findsOneWidget);

      // Market name and date must be present
      expect(find.text('• Date: 2026-10-24'), findsOneWidget);
    });
  });
}
