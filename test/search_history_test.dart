import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/models/crop_model.dart';
import 'package:sancharya/services/history/search_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tomatoCrop = Crop(
    id: 'crop_tomato',
    nameEn: 'Tomato',
    nameHi: 'टमाटर',
    category: 'Vegetables',
    standardShelfLifeDays: 5,
    benchmarkPricePerQuintal: 2200.0,
  );

  const wheatCrop = Crop(
    id: 'crop_wheat',
    nameEn: 'Wheat',
    nameHi: 'गेहूं',
    category: 'Grains',
    standardShelfLifeDays: 180,
    benchmarkPricePerQuintal: 2500.0,
  );

  CombinedCropAnalysisResult createDummyResult({
    required String id,
    required Crop crop,
    required String location,
    required double quantity,
    required DateTime timestamp,
  }) {
    final input = CropAnalysisInput(
      crop: crop,
      location: location,
      quantity: quantity,
      quantityUnit: QuantityUnit.quintal,
      harvestDate: timestamp.subtract(const Duration(days: 1)),
      condition: CropCondition.good,
    );

    const risk = SpoilageRiskAssessment(
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

    const bench = MarketPriceBenchmark(
      currentAvgPricePerQuintal: 2200.0,
      predictedFuturePricePerQuintal: 2400.0,
      minExpectedPrice: 2000.0,
      maxExpectedPrice: 2600.0,
      trend: PriceTrend.rising,
      expectedPriceChangePercent: 9.1,
      mandiName: 'Pune APMC',
      district: 'Pune',
      state: 'Maharashtra',
      fallbackLevel: 'district',
      requestedDistrict: 'Pune',
    );

    const rec = SellingRecommendation(
      action: SellingAction.sellNow,
      headlineEn: 'Sell at nearby APMC within 2 days',
      headlineHi: '2 दिनों में नजदीकी मंडी में बेचें',
      rationaleEn: 'Good current price',
      rationaleHi: 'अच्छा मूल्य',
      estimatedNetAdvantagePerQuintal: 150.0,
      nextStepsEn: [],
      nextStepsHi: [],
    );

    return CombinedCropAnalysisResult(
      analysisId: id,
      timestamp: timestamp,
      input: input,
      spoilageRisk: risk,
      marketBenchmark: bench,
      recommendation: rec,
      nearbyResources: const [],
      isSimulatedModel: false,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('SearchHistoryService - Farmer Search History Tests', () {
    test('Empty history displays empty list initially', () async {
      final list = await SearchHistoryService.getRecentAnalyses();
      expect(list, isEmpty);
    });

    test('Completed search appears in history', () async {
      final now = DateTime.now();
      final res = createDummyResult(
        id: 'analysis_1',
        crop: tomatoCrop,
        location: 'Pune, Maharashtra',
        quantity: 25.0,
        timestamp: now,
      );

      final saved = await SearchHistoryService.saveAnalysis(res);
      expect(saved, isTrue);

      final list = await SearchHistoryService.getRecentAnalyses();
      expect(list.length, 1);
      expect(list.first.input.crop.nameEn, 'Tomato');
      expect(list.first.input.location, 'Pune, Maharashtra');
      expect(list.first.input.quantity, 25.0);
    });

    test('Multiple searches are ordered newest first', () async {
      final t1 = DateTime(2026, 11, 1, 10, 0);
      final t2 = DateTime(2026, 11, 2, 12, 0);
      final t3 = DateTime(2026, 11, 2, 15, 30);

      final r1 = createDummyResult(id: 'a1', crop: tomatoCrop, location: 'Pune', quantity: 10, timestamp: t1);
      final r2 = createDummyResult(id: 'a2', crop: wheatCrop, location: 'Nashik', quantity: 50, timestamp: t2);
      final r3 = createDummyResult(id: 'a3', crop: tomatoCrop, location: 'Agra', quantity: 15, timestamp: t3);

      await SearchHistoryService.saveAnalysis(r1);
      await SearchHistoryService.saveAnalysis(r2);
      await SearchHistoryService.saveAnalysis(r3);

      final list = await SearchHistoryService.getRecentAnalyses();
      expect(list.length, 3);
      expect(list[0].analysisId, 'a3', reason: 'Newest (t3) must be first');
      expect(list[1].analysisId, 'a2');
      expect(list[2].analysisId, 'a1');
    });

    test('History survives simulated app restart via persistent storage', () async {
      final t1 = DateTime(2026, 11, 2, 14, 0);
      final r1 = createDummyResult(id: 'persist_1', crop: wheatCrop, location: 'Kanpur', quantity: 30, timestamp: t1);

      await SearchHistoryService.saveAnalysis(r1);

      // Verify entries in persistent store
      final listBeforeRestart = await SearchHistoryService.getRecentAnalyses();
      expect(listBeforeRestart.length, 1);

      // Simulate app restart by re-reading from SharedPreferences
      final listAfterRestart = await SearchHistoryService.getRecentAnalyses();
      expect(listAfterRestart.length, 1);
      expect(listAfterRestart.first.input.crop.nameEn, 'Wheat');
      expect(listAfterRestart.first.input.location, 'Kanpur');
    });

    test('Tapping entry restores accurate crop, location and quantity details', () async {
      final r = createDummyResult(
        id: 'tap_test',
        crop: tomatoCrop,
        location: 'Nashik, Maharashtra',
        quantity: 40.0,
        timestamp: DateTime.now(),
      );

      await SearchHistoryService.saveAnalysis(r);
      final list = await SearchHistoryService.getRecentAnalyses();
      final restored = list.first;

      expect(restored.input.crop.id, 'crop_tomato');
      expect(restored.input.crop.nameEn, 'Tomato');
      expect(restored.input.crop.nameHi, 'टमाटर');
      expect(restored.input.location, 'Nashik, Maharashtra');
      expect(restored.input.quantity, 40.0);
      expect(restored.input.quantityUnit, QuantityUnit.quintal);
      expect(restored.marketBenchmark.currentAvgPricePerQuintal, 2200.0);
    });

    test('Invalid or incomplete searches are not saved', () async {
      // Empty location
      final emptyLocInput = CropAnalysisInput(
        crop: tomatoCrop,
        location: '   ',
        quantity: 10,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now(),
        condition: CropCondition.good,
      );
      final badResult = CombinedCropAnalysisResult(
        analysisId: 'bad_1',
        timestamp: DateTime.now(),
        input: emptyLocInput,
        spoilageRisk: const SpoilageRiskAssessment(
          riskLevel: SpoilageRiskLevel.low,
          riskScore: 10,
          safeShelfLifeDaysRemaining: 5,
          explanationEn: '',
          explanationHi: '',
          criticalRiskFactorsEn: [],
          criticalRiskFactorsHi: [],
          preservationTipsEn: [],
          preservationTipsHi: [],
        ),
        marketBenchmark: const MarketPriceBenchmark(
          currentAvgPricePerQuintal: 0,
          predictedFuturePricePerQuintal: 0,
          minExpectedPrice: 0,
          maxExpectedPrice: 0,
          trend: PriceTrend.stable,
          expectedPriceChangePercent: 0,
          mandiName: '',
          district: null,
          state: null,
          fallbackLevel: 'none',
          requestedDistrict: '',
        ),
        recommendation: const SellingRecommendation(
          action: SellingAction.sellNow,
          headlineEn: '',
          headlineHi: '',
          rationaleEn: '',
          rationaleHi: '',
          estimatedNetAdvantagePerQuintal: 0,
          nextStepsEn: [],
          nextStepsHi: [],
        ),
        nearbyResources: const [],
        isSimulatedModel: false,
      );

      final saved = await SearchHistoryService.saveAnalysis(badResult);
      expect(saved, isFalse);

      final list = await SearchHistoryService.getRecentAnalyses();
      expect(list, isEmpty);
    });

    test('Rapid repeated rebuilds / duplicate submissions do not create duplicate entries', () async {
      final now = DateTime.now();
      final r1 = createDummyResult(id: 'dup_1', crop: tomatoCrop, location: 'Pune', quantity: 20, timestamp: now);
      final r2 = createDummyResult(
        id: 'dup_2',
        crop: tomatoCrop,
        location: 'Pune',
        quantity: 20,
        timestamp: now.add(const Duration(seconds: 15)),
      );

      await SearchHistoryService.saveAnalysis(r1);
      await SearchHistoryService.saveAnalysis(r2); // Repeated callback within 15 seconds

      final list = await SearchHistoryService.getRecentAnalyses();
      expect(list.length, 1, reason: 'Duplicate search within 2 minutes must be deduplicated to 1 entry');
    });

    test('History is scoped per authenticated user phone number', () async {
      final now = DateTime.now();
      final user1Result = createDummyResult(id: 'u1_1', crop: tomatoCrop, location: 'Pune', quantity: 10, timestamp: now);
      final user2Result = createDummyResult(id: 'u2_1', crop: wheatCrop, location: 'Agra', quantity: 50, timestamp: now);

      await SearchHistoryService.saveAnalysis(user1Result, userPhone: '9876543210');
      await SearchHistoryService.saveAnalysis(user2Result, userPhone: '9123456780');

      final user1History = await SearchHistoryService.getRecentAnalyses(userPhone: '9876543210');
      final user2History = await SearchHistoryService.getRecentAnalyses(userPhone: '9123456780');

      expect(user1History.length, 1);
      expect(user1History.first.input.crop.nameEn, 'Tomato');

      expect(user2History.length, 1);
      expect(user2History.first.input.crop.nameEn, 'Wheat');
    });
  });
}
