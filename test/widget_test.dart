import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/app.dart';
import 'package:sancharya/core/constants/app_constants.dart';
import 'package:sancharya/data/demo_data/demo_crops.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/screens/crop_results/crop_results_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SANCHARYA app smoke test loads brand and splash', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const SancharyaApp());

    // Verify brand name appears on splash screen
    expect(find.text(AppConstants.appName), findsWidgets);

    // Pump past the 1400ms splash delay to navigate to Language screen
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 500));

    // Confirm that language selection screen has loaded
    expect(find.text(AppConstants.appName), findsWidgets);
  });

  testWidgets('CropResultsScreen renders without overflow on narrow 320px viewport for verified live price', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final input = CropAnalysisInput(
      crop: DemoCrops.sampleCrops.first,
      location: 'Agra, Uttar Pradesh',
      quantity: 50,
      quantityUnit: QuantityUnit.quintal,
      harvestDate: DateTime.now().subtract(const Duration(days: 2)),
      condition: CropCondition.good,
      latitude: 27.1767,
      longitude: 78.0081,
    );

    const benchmark = MarketPriceBenchmark(
      currentAvgPricePerQuintal: 1400.0,
      predictedFuturePricePerQuintal: 0.0,
      minExpectedPrice: 1200.0,
      maxExpectedPrice: 1600.0,
      trend: PriceTrend.stable,
      expectedPriceChangePercent: 0.0,
      mandiName: 'Samsabad APMC, Agra (Agmarknet Live)',
      market: 'Samsabad APMC',
      district: 'Agra',
      state: 'Uttar Pradesh',
      arrivalDate: '26/10/2026',
      fallbackLevel: 'district',
      requestedDistrict: 'Agra',
      distanceKm: 0.0,
      isPredictionModelConnected: false,
      isLiveMandiData: true,
      priceUnit: '₹/quintal',
    );

    const spoilage = SpoilageRiskAssessment(
      riskLevel: SpoilageRiskLevel.low,
      riskScore: 20,
      safeShelfLifeDaysRemaining: 10,
      explanationEn: 'Sound condition',
      explanationHi: 'सुरक्षित फसल',
      criticalRiskFactorsEn: [],
      criticalRiskFactorsHi: [],
      preservationTipsEn: [],
      preservationTipsHi: [],
    );

    const recommendation = SellingRecommendation(
      action: SellingAction.holdNormal,
      headlineEn: 'Hold in Ventilated Storage',
      headlineHi: 'हवादार भंडार में सुरक्षित रखें',
      rationaleEn: 'Market prices steady',
      rationaleHi: 'बाजार भाव स्थिर हैं',
      estimatedNetAdvantagePerQuintal: 100.0,
      nextStepsEn: ['Inspect daily'],
      nextStepsHi: ['दैनिक निरीक्षण करें'],
    );

    final result = CombinedCropAnalysisResult(
      analysisId: 'NARROW-LIVE-TEST',
      timestamp: DateTime.now(),
      input: input,
      spoilageRisk: spoilage,
      marketBenchmark: benchmark,
      recommendation: recommendation,
      nearbyResources: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CropResultsScreen(result: result),
      ),
    );
    await tester.pumpAndSettle();

    // Verify key live mandi elements rendered without overflow
    expect(find.textContaining('1400'), findsWidgets);
    expect(find.text('Prediction Unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CropResultsScreen renders Data Not Available without overflow on narrow 320px viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final input = CropAnalysisInput(
      crop: DemoCrops.sampleCrops.first,
      location: 'Kanpur Nagar, Uttar Pradesh',
      quantity: 50,
      quantityUnit: QuantityUnit.quintal,
      harvestDate: DateTime.now().subtract(const Duration(days: 2)),
      condition: CropCondition.good,
    );

    const benchmark = MarketPriceBenchmark(
      currentAvgPricePerQuintal: 0.0,
      predictedFuturePricePerQuintal: 0.0,
      minExpectedPrice: 0.0,
      maxExpectedPrice: 0.0,
      trend: PriceTrend.stable,
      expectedPriceChangePercent: 0.0,
      mandiName: 'Kanpur Nagar (Data Not Available)',
      fallbackLevel: 'none',
      requestedDistrict: 'Kanpur Nagar',
      noticeMessageEn: 'Data Not Available',
      noticeMessageHi: 'डेटा उपलब्ध नहीं है',
      isPredictionModelConnected: false,
      isLiveMandiData: false,
      priceUnit: '₹/quintal',
    );

    const spoilage = SpoilageRiskAssessment(
      riskLevel: SpoilageRiskLevel.low,
      riskScore: 20,
      safeShelfLifeDaysRemaining: 10,
      explanationEn: 'Sound condition',
      explanationHi: 'सुरक्षित फसल',
      criticalRiskFactorsEn: [],
      criticalRiskFactorsHi: [],
      preservationTipsEn: [],
      preservationTipsHi: [],
    );

    const recommendation = SellingRecommendation(
      action: SellingAction.holdNormal,
      headlineEn: 'Hold in Ventilated Storage',
      headlineHi: 'हवादार भंडार में सुरक्षित रखें',
      rationaleEn: 'Produce condition is stable',
      rationaleHi: 'फसल की स्थिति स्थिर है',
      estimatedNetAdvantagePerQuintal: 0.0,
      nextStepsEn: ['Confirm morning modal prices directly with local APMC yard'],
      nextStepsHi: ['स्थानीय मंडी यार्ड से भाव की पुष्टि करें'],
    );

    final result = CombinedCropAnalysisResult(
      analysisId: 'NARROW-NO-DATA-TEST',
      timestamp: DateTime.now(),
      input: input,
      spoilageRisk: spoilage,
      marketBenchmark: benchmark,
      recommendation: recommendation,
      nearbyResources: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CropResultsScreen(result: result),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data Not Available'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CropResultsScreen renders verified CEDA price forecast with MAPE badge and attribution', (WidgetTester tester) async {
    final input = CropAnalysisInput(
      crop: DemoCrops.sampleCrops.first,
      location: 'Agra, Uttar Pradesh',
      quantity: 40,
      quantityUnit: QuantityUnit.quintal,
      harvestDate: DateTime.now().subtract(const Duration(days: 1)),
      condition: CropCondition.good,
    );

    const benchmark = MarketPriceBenchmark(
      currentAvgPricePerQuintal: 1900.0,
      predictedFuturePricePerQuintal: 2154.0,
      minExpectedPrice: 2040.0,
      maxExpectedPrice: 2268.0,
      trend: PriceTrend.rising,
      expectedPriceChangePercent: 13.4,
      mandiName: 'Agra APMC, Agra (Imported Dataset)',
      market: 'Agra APMC',
      district: 'Agra',
      state: 'Uttar Pradesh',
      arrivalDate: '2025-10-07',
      fallbackLevel: 'district',
      requestedDistrict: 'Agra',
      isPredictionModelConnected: true,
      isGenuineHoldout: true,
      holdoutMape: 0.0,
      forecastModelName: "Holt's Double Exponential Smoothing",
      forecastPeriod: '2025-10-01 to 2025-10-07',
      historicalObservationCount: 7,
      isDatasetRecord: true,
      priceUnit: '₹/quintal',
    );

    const spoilage = SpoilageRiskAssessment(
      riskLevel: SpoilageRiskLevel.low,
      riskScore: 25,
      safeShelfLifeDaysRemaining: 7,
      explanationEn: 'Good condition',
      explanationHi: 'अच्छी स्थिति',
      criticalRiskFactorsEn: [],
      criticalRiskFactorsHi: [],
      preservationTipsEn: [],
      preservationTipsHi: [],
    );

    const recommendation = SellingRecommendation(
      action: SellingAction.holdNormal,
      headlineEn: 'Hold for Market Trend',
      headlineHi: 'मंडी में तेजी की प्रतीक्षा करें',
      rationaleEn: 'Rising market price trend detected',
      rationaleHi: 'मंडी में तेजी का रुख है',
      estimatedNetAdvantagePerQuintal: 254.0,
      nextStepsEn: ['Monitor daily auctions'],
      nextStepsHi: ['दैनिक नीलामी पर नजर रखें'],
    );

    final result = CombinedCropAnalysisResult(
      analysisId: 'CEDA-VERIFIED-FORECAST-TEST',
      timestamp: DateTime.now(),
      input: input,
      spoilageRisk: spoilage,
      marketBenchmark: benchmark,
      recommendation: recommendation,
      nearbyResources: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CropResultsScreen(result: result),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1900'), findsWidgets);
    expect(find.textContaining('2154'), findsWidgets);
    expect(find.textContaining('+13.4%'), findsOneWidget);
    expect(find.text('MAPE: 0.0%'), findsOneWidget);
    expect(find.textContaining('CEDA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

