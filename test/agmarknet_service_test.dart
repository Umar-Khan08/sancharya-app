import 'package:flutter_test/flutter_test.dart';
import 'package:sancharya/data/demo_data/demo_crops.dart';
import 'package:sancharya/models/agri_resource.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/services/agriculture/agmarknet_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgmarknetAgricultureService Tests', () {
    late AgmarknetAgricultureService agmarknetService;

    setUp(() {
      agmarknetService = AgmarknetAgricultureService();
    });

    test('Flutter API timeout is configured to 12 seconds', () {
      expect(AgmarknetAgricultureService.defaultTimeout, const Duration(seconds: 12));
      expect(agmarknetService.timeout, const Duration(seconds: 12));
    });

    test('Graceful handling when backend returns mandi price or data not available', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Nashik, Maharashtra',
        quantity: 25,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      final result = await agmarknetService.analyzeCrop(input);

      expect(result, isNotNull);
      expect(result.input.crop.id, 'tomato');
      expect(result.spoilageRisk, isNotNull);
      expect(result.recommendation.headlineEn.isNotEmpty, true);
    });

    test('Data Not Available benchmark clearly identifies absence of live records without price substitution', () {
      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 0.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 0.0,
        maxExpectedPrice: 0.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Lucknow (Data Not Available)',
        district: 'Lucknow',
        state: 'Uttar Pradesh',
        fallbackLevel: 'none',
        requestedDistrict: 'Lucknow',
        noticeMessageEn: 'Data Not Available',
        noticeMessageHi: 'डेटा उपलब्ध नहीं है',
        isPredictionModelConnected: false,
        isLiveMandiData: false,
        priceUnit: '₹/quintal',
      );

      expect(benchmark.hasLiveRecord, false);
      expect(benchmark.isDataNotAvailable, true);
      expect(benchmark.isNetworkError, false);
      expect(benchmark.currentAvgPricePerQuintal, 0.0);
      expect(benchmark.predictedFuturePricePerQuintal, 0.0);
      expect(benchmark.noticeMessage(false), 'Data Not Available');
      expect(benchmark.noticeMessage(true), 'डेटा उपलब्ध नहीं है');
    });

    test('Network error benchmark clearly distinguishes API failure from missing data', () {
      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 0.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 0.0,
        maxExpectedPrice: 0.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Lucknow (Unable to fetch data)',
        district: 'Lucknow',
        state: 'Uttar Pradesh',
        fallbackLevel: 'error',
        requestedDistrict: 'Lucknow',
        noticeMessageEn: 'Unable to fetch data. Please try again.',
        noticeMessageHi: 'डेटा प्राप्त करने में असमर्थ। कृपया पुनः प्रयास करें।',
        isPredictionModelConnected: false,
        isLiveMandiData: false,
        priceUnit: '₹/quintal',
      );

      expect(benchmark.hasLiveRecord, false);
      expect(benchmark.isNetworkError, true);
      expect(benchmark.isDataNotAvailable, false);
      expect(benchmark.noticeMessage(false), 'Unable to fetch data. Please try again.');
      expect(benchmark.noticeMessage(true), 'डेटा प्राप्त करने में असमर्थ। कृपया पुनः प्रयास करें।');
    });

    test('Service returns Data Not Available or error without fake price substitution', () async {
      final onionCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'onion');
      final input = CropAnalysisInput(
        crop: onionCrop,
        location: 'NonExistentDistrictXYZ, Nowhere',
        quantity: 15,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      final testFallbackService = AgmarknetAgricultureService(
        timeout: const Duration(microseconds: 1),
      );

      final result = await testFallbackService.analyzeCrop(input);
      expect(result.marketBenchmark.hasLiveRecord, false);
      expect(result.marketBenchmark.currentAvgPricePerQuintal, 0.0);
      expect(result.marketBenchmark.predictedFuturePricePerQuintal, 0.0);
    });

    test('Unit conversion: pricePerKg accurately computes 1/100th of Quintal rate', () {
      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2400.0,
        predictedFuturePricePerQuintal: 2520.0,
        minExpectedPrice: 2100.0,
        maxExpectedPrice: 2700.0,
        trend: PriceTrend.rising,
        expectedPriceChangePercent: 5.0,
        mandiName: 'Lasalgaon APMC',
        isPredictionModelConnected: false,
        isLiveMandiData: true,
        priceUnit: '₹/quintal',
      );

      expect(benchmark.pricePerKg, 24.0);
      expect(benchmark.predictedFuturePricePerKg, 25.2);
    });

    test('Verified district mandi record clearly displays market, arrival date, and suppresses prediction when model unconnected', () {
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
        noticeMessageEn: 'Verified live mandi price for Agra (Arrival: 26/10/2026)',
        noticeMessageHi: 'Agra के लिए सत्यापित लाइव मंडी भाव (आवक: 26/10/2026)',
        isPredictionModelConnected: false,
        isLiveMandiData: true,
        priceUnit: '₹/quintal',
      );

      expect(benchmark.hasLiveRecord, true);
      expect(benchmark.isDistrictLive, true);
      expect(benchmark.hasValidPrediction, false);
      expect(benchmark.market, 'Samsabad APMC');
      expect(benchmark.district, 'Agra');
      expect(benchmark.pricePerKg, 14.0);
      expect(benchmark.noticeMessage(false), contains('Verified live mandi price'));
    });


    test('Synthetic demonstration forecast suppresses holdout MAPE and verified model status', () {
      const demoBenchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 1850.0,
        predictedFuturePricePerQuintal: 1772.0,
        minExpectedPrice: 1600.0,
        maxExpectedPrice: 2000.0,
        trend: PriceTrend.falling,
        expectedPriceChangePercent: -4.2,
        mandiName: 'Demonstration Benchmark Data (Live rates unavailable)',
        isPredictionModelConnected: false,
        isLiveMandiData: false,
        isGenuineHoldout: false,
        holdoutMape: null, // Strictly suppressed for synthetic demonstration
        forecastModelName: "Holt's Double Exponential Smoothing (Simulation)",
        noticeMessageEn: 'Demonstration Forecast — Not Validated on Historical Mandi Data.',
        noticeMessageHi: 'प्रदर्शन पूर्वानुमान — ऐतिहासिक मंडी डेटा पर सत्यापित नहीं।',
      );

      expect(demoBenchmark.hasVerifiedAccuracy, false);
      expect(demoBenchmark.holdoutMape, isNull);
      expect(demoBenchmark.isGenuineHoldout, false);
      expect(demoBenchmark.isPredictionModelConnected, false);
      expect(demoBenchmark.isDemonstration, true);
    });

    test('Resource card verification notice describes only verified physical location and distance', () {
      final resource = AgriResource(
        id: 'osm_12345',
        nameEn: 'Kanpur APMC Yard',
        nameHi: 'कानपुर मंडी यार्ड',
        type: AgriResourceType.mandi,
        districtEn: 'Kanpur Nagar',
        districtHi: 'कानपुर नगर',
        distanceKm: 4.5,
        capacityMetricTons: 0,
        availableMetricTons: 0,
        contactPhone: '',
        estimatedRatePerMonthPerQuintal: 0,
        isGovernmentAccredited: true,
        isSimulatedData: false,
        isOsmMapped: true,
        hasLiveAgmarknetPrice: false,
        isCapacityVerified: false,
        isPhoneVerified: false,
        verificationNoticeEn: 'Mapped market location — Verified physical location and distance',
        verificationNoticeHi: 'मैप पर दर्ज मंडी — सत्यापित भौतिक स्थान और दूरी',
      );

      expect(resource.verificationNotice(false), contains('Verified physical location and distance'));
      expect(resource.verificationNotice(false), isNot(contains('Verified live arrival prices shown above via Agmarknet')));
      expect(resource.verificationNotice(true), contains('सत्यापित भौतिक स्थान और दूरी'));
    });

    test('Automatic fallback: falls back to LocalMandiService when backend primary is offline', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Ludhiana, Punjab',
        quantity: 10,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      // Timeout fast on backend to force offline fallback
      final service = AgmarknetAgricultureService(
        timeout: const Duration(milliseconds: 1),
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      // Successfully resolved via LocalMandiService fallback
      expect(benchmark.hasLiveRecord, true);
      expect(benchmark.isLiveMandiData, false);
      expect(benchmark.isDatasetRecord, true);
      expect(benchmark.isOfflineLocal, true);
      expect(benchmark.currentAvgPricePerQuintal, greaterThan(0));
      expect(benchmark.pricePerKg, benchmark.currentAvgPricePerQuintal / 100.0);
      expect(benchmark.lastVerifiedDate, isNotEmpty);
      expect(benchmark.district?.toLowerCase(), 'ludhiana');
      expect(benchmark.noticeMessage(false), contains('Offline Mandi Dataset Record'));
    });

    test('Strict matching in fallback: never invents price for unmatched location/crop', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'NowhereDistrict999, UnknownState',
        quantity: 5,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now(),
        condition: CropCondition.good,
      );

      final service = AgmarknetAgricultureService(
        timeout: const Duration(milliseconds: 1),
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      expect(benchmark.hasLiveRecord, false);
      expect(benchmark.currentAvgPricePerQuintal, 0.0);
      expect(benchmark.isDataNotAvailable, true);
      expect(benchmark.noticeMessage(false), 'Data Not Available');
      expect(result.grossCropValue, isNull);
    });

    test('Historical/stale benchmark preserves actual observation date and attribution', () {
      const histBenchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2150.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 1850.0,
        maxExpectedPrice: 2400.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Agra APMC, Agra (CEDA Historical)',
        district: 'Agra',
        state: 'Uttar Pradesh',
        arrivalDate: '2025-10-01',
        fallbackLevel: 'district',
        isPredictionModelConnected: false,
        isLiveMandiData: false,
        isDatasetRecord: false,
        isHistorical: true,
        isStale: true,
        sourceName: 'CEDA Agri-Market (Ashoka University)',
        lastVerifiedDate: '2025-10-01',
        priceUnit: '₹/quintal',
      );

      expect(histBenchmark.isHistorical, true);
      expect(histBenchmark.isStale, true);
      expect(histBenchmark.isStaleRecord, true);
      expect(histBenchmark.isLiveMandiData, false);
      expect(histBenchmark.arrivalDate, '2025-10-01');
      expect(histBenchmark.sourceName, contains('CEDA'));
      expect(histBenchmark.pricePerKg, 21.5);
    });

    test('Backend CSV configuration does not preempt Flutter LocalMandiService fallback', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Ludhiana, Punjab',
        quantity: 10,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      // Force backend timeout / unavailability to ensure LocalMandiService with assets/data/mandis.json is reached
      final service = AgmarknetAgricultureService(
        timeout: const Duration(milliseconds: 1),
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      // Confirms LocalMandiService was reached and used assets/data/mandis.json
      expect(benchmark.isOfflineLocal, true);
      expect(benchmark.isLiveMandiData, false);
      expect(benchmark.sourceName, contains('assets/data/mandis.json'));
      expect(benchmark.currentAvgPricePerQuintal, greaterThan(0));
      expect(benchmark.pricePerKg, benchmark.currentAvgPricePerQuintal / 100.0);
      expect(benchmark.lastVerifiedDate, isNotEmpty);
    });

    test('Distinguishes live, database-backed, historical, dataset, and rejected observations', () {
      // 1. Live observation
      const live = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2500.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 2400.0,
        maxExpectedPrice: 2600.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Pune APMC (Agmarknet Live)',
        isLiveMandiData: true,
        isDatabaseRecord: false,
        isDatasetRecord: false,
        isHistorical: false,
      );
      expect(live.hasLiveRecord, true);
      expect(live.isDistrictLive, true);
      expect(live.isStoredDatabaseObservation, false);
      expect(live.isOfflineLocal, false);

      // 2. Database-backed observation (never labeled as live)
      const dbObs = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2400.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 2200.0,
        maxExpectedPrice: 2500.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Pune APMC (data.gov.in Stored)',
        isLiveMandiData: false,
        isDatabaseRecord: true,
        isDatasetRecord: false,
        isHistorical: false,
        sourceName: 'data.gov.in (Database)',
      );
      expect(dbObs.hasLiveRecord, true);
      expect(dbObs.isDistrictLive, false, reason: 'Database stored observations must NEVER be labeled as live');
      expect(dbObs.isStoredDatabaseObservation, true);
      expect(dbObs.isOfflineLocal, false);

      // 3. Offline local dataset observation
      const local = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2200.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 2000.0,
        maxExpectedPrice: 2400.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Pune APMC (Offline Dataset)',
        isLiveMandiData: false,
        isDatabaseRecord: false,
        isDatasetRecord: true,
        isHistorical: false,
        sourceName: 'mandis.json',
      );
      expect(local.hasLiveRecord, true);
      expect(local.isDistrictLive, false);
      expect(local.isOfflineLocal, true);
      expect(local.isStoredDatabaseObservation, false);

      // 4. Historical observation
      const hist = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 2100.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 1900.0,
        maxExpectedPrice: 2300.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'Pune APMC (CEDA Historical)',
        isLiveMandiData: false,
        isDatabaseRecord: false,
        isDatasetRecord: false,
        isHistorical: true,
      );
      expect(hist.hasLiveRecord, true);
      expect(hist.isDistrictLive, false);
      expect(hist.isHistorical, true);

      // 5. Rejected observation
      const rej = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 0.0,
        predictedFuturePricePerQuintal: 0.0,
        minExpectedPrice: 0.0,
        maxExpectedPrice: 0.0,
        trend: PriceTrend.stable,
        expectedPriceChangePercent: 0.0,
        mandiName: 'None',
        isLiveMandiData: false,
        statusReason: 'rejected',
      );
      expect(rej.hasLiveRecord, false);
      expect(rej.isRejectedRecord, true);
      expect(rej.isDataNotAvailable, true);
    });
  });
}


