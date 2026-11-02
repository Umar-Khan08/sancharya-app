import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sancharya/data/demo_data/demo_crops.dart';
import 'package:sancharya/models/crop_analysis_input.dart';
import 'package:sancharya/models/crop_analysis_result.dart';
import 'package:sancharya/services/agriculture/agmarknet_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mandi Price Source Policy & mandis.json Elimination Tests', () {
    test('assets/data/mandis.json is completely removed from app bundle', () async {
      // Confirms assets/data/mandis.json no longer exists and cannot be loaded
      expect(
        () async => await rootBundle.loadString('assets/data/mandis.json'),
        throwsA(isA<FlutterError>()),
      );
    });

    test('API failure never falls back to static prices for Nashik Tomato (never returns 1991)', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Chandwad, Nashik, Maharashtra',
        quantity: 10,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      // Backend is completely offline / unreachable
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      final service = AgmarknetAgricultureService(
        client: mockClient,
        backendBaseUrl: 'http://testserver',
        timeout: const Duration(milliseconds: 100),
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      // Must return clean Data Not Available without any static price
      expect(benchmark.currentAvgPricePerQuintal, 0.0);
      expect(benchmark.currentAvgPricePerQuintal, isNot(1991.0));
      expect(benchmark.predictedFuturePricePerQuintal, 0.0);
      expect(benchmark.predictedFuturePricePerQuintal, isNot(1991.0));
      expect(benchmark.hasLiveRecord, false);
      expect(benchmark.isDataNotAvailable, true);
      expect(result.grossCropValue, isNull);
      expect(benchmark.sourceName ?? '', isNot(contains('mandis.json')));
    });

    test('CEDA Agmarknet direct API is sole source for historical mandi prices and holdout forecasts', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Nashik, Maharashtra',
        quantity: 20,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/mandi-prices')) {
          // data.gov.in has no daily records today for Nashik Tomato
          return http.Response(
            jsonEncode({
              'success': false,
              'records': [],
              'message': 'No live records found for Nashik',
              'fallback_level': 'error',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (request.url.path.contains('/api/forecasting/price-forecast')) {
          // CEDA Agmarknet API returns genuine historical observation and holdout forecast
          return http.Response(
            jsonEncode({
              'success': true,
              'has_prediction': true,
              'commodity': 'Tomato',
              'market': 'APMC Market 168',
              'district': 'Nashik',
              'state': 'Maharashtra',
              'forecast_horizon_days': 7,
              'predicted_future_price_per_quintal': 341.2,
              'current_observed_price': 525.0,
              'min_expected_price': 367.5,
              'max_expected_price': 506.4,
              'expected_change_percent': -35.0,
              'trend': 'falling',
              'historical_points_used': 255,
              'source_period_start': '2025-01-01',
              'source_period_end': '2025-10-29',
              'model_name': "Holt's Double Exponential Smoothing",
              'data_source': 'CEDA Ashoka Agmarknet Historical Prices',
              'is_genuine_model': true,
              'is_genuine_holdout': true,
              'holdout_mape': 16.75,
              'disclaimer_en': "Holdout evaluated (Holt's Double Exponential Smoothing, Test MAPE: 16.75%).",
              'disclaimer_hi': "क्रोनोलॉजिकल होल्डआउट टेस्ट से मूल्यांकित।",
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = AgmarknetAgricultureService(
        client: mockClient,
        backendBaseUrl: 'http://testserver',
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      // Confirms CEDA Agmarknet is the sole source:
      // Real CEDA observed price = 525.0, NOT the static 1991 from old mandis.json
      expect(benchmark.currentAvgPricePerQuintal, 525.0);
      expect(benchmark.pricePerKg, 5.25);
      expect(benchmark.currentAvgPricePerQuintal, isNot(1991.0));
      expect(benchmark.predictedFuturePricePerQuintal, 341.2);
      expect(benchmark.trend, PriceTrend.falling);
      expect(benchmark.expectedPriceChangePercent, -35.0);
      expect(benchmark.arrivalDate, '2025-10-29');
      expect(benchmark.market, 'APMC Market 168');
      expect(benchmark.district, 'Nashik');
      expect(benchmark.state, 'Maharashtra');
      expect(benchmark.sourceName, contains('CEDA'));
      expect(benchmark.sourceUrl, contains('ceda.ashoka.edu.in'));
      expect(benchmark.isLiveMandiData, false);
      expect(benchmark.isHistorical, true);
      expect(benchmark.isStale, true);
      expect(benchmark.isDatasetRecord, false);
      expect(benchmark.isGenuineHoldout, true);
      expect(benchmark.holdoutMape, 16.75);
      expect(benchmark.hasLiveRecord, true);
      expect(result.grossCropValue, 525.0 * 20); // 10,500
    });

    test('When CEDA forecast returns no observation or prediction, clear unavailable state is shown', () async {
      final potatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'potato');
      final input = CropAnalysisInput(
        crop: potatoCrop,
        location: 'RemoteVillage, UnknownDistrict',
        quantity: 15,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'has_prediction': false,
            'current_observed_price': null,
            'disclaimer_en': 'Price prediction unavailable because sufficient historical price data is not available.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AgmarknetAgricultureService(
        client: mockClient,
        backendBaseUrl: 'http://testserver',
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      expect(benchmark.currentAvgPricePerQuintal, 0.0);
      expect(benchmark.predictedFuturePricePerQuintal, 0.0);
      expect(benchmark.hasLiveRecord, false);
      expect(benchmark.isDataNotAvailable, true);
      expect(benchmark.noticeMessage(false), 'Data Not Available');
      expect(result.grossCropValue, isNull);
    });

    test('Regression: Daily records absent (returns CSV fallback) -> CEDA historical price 525 is displayed with historical label and Gross Crop Value', () async {
      final tomatoCrop = DemoCrops.sampleCrops.firstWhere((c) => c.id == 'tomato');
      final input = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Chandwad, Nashik, Maharashtra',
        quantity: 25,
        quantityUnit: QuantityUnit.quintal,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );

      final mockClient = MockClient((request) async {
        // Daily mandi endpoint returns CSV fallback (is_live_data: false, active_source: "csv")
        if (request.url.path.contains('/api/mandi-prices')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'commodity': 'Tomato',
              'records_count': 1,
              'records': [
                {
                  'commodity': 'Tomato',
                  'market': 'APMC Ghoti',
                  'district': 'Nashik',
                  'state': 'Maharashtra',
                  'modal_price_per_quintal': 950.0,
                  'source_name': 'Local Agricultural Mandi Dataset',
                  'is_stale': true,
                  'is_historical': false,
                }
              ],
              'active_source': 'csv',
              'is_live_data': false,
              'fallback_level': 'district',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // CEDA price-forecast endpoint returns genuine Nashik Tomato observation 525.0
        if (request.url.path.contains('/api/forecasting/price-forecast')) {
          expect(request.url.queryParameters['district'], 'Nashik');
          return http.Response(
            jsonEncode({
              'success': true,
              'has_prediction': true,
              'commodity': 'Tomato',
              'market': 'APMC Market 168',
              'district': 'Nashik',
              'state': 'Maharashtra',
              'horizon_days': 7,
              'current_observed_price': 525.0,
              'predicted_future_price_per_quintal': 341.2,
              'min_expected_price': 272.96,
              'max_expected_price': 409.44,
              'trend': 'falling',
              'expected_change_percent': -35.0,
              'historical_points_used': 19,
              'source_period_start': '2025-01-01',
              'source_period_end': '2025-10-29',
              'model_name': "Holt's Double Exponential Smoothing",
              'data_source': 'CEDA Ashoka Agmarknet Historical Prices',
              'is_genuine_model': true,
              'is_genuine_holdout': true,
              'holdout_mape': 16.75,
              'disclaimer_en': "Forecast evaluated against genuine historical observations using a chronological holdout test set.",
              'disclaimer_hi': "वास्तविक ऐतिहासिक आंकड़ों द्वारा मूल्यांकित पूर्वानुमान।",
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = AgmarknetAgricultureService(
        client: mockClient,
        backendBaseUrl: 'http://testserver',
      );

      final result = await service.analyzeCrop(input);
      final benchmark = result.marketBenchmark;

      // 1. Observed price is 525.0 from CEDA historical observation
      expect(benchmark.currentAvgPricePerQuintal, 525.0);
      expect(benchmark.pricePerKg, 5.25);
      expect(benchmark.predictedFuturePricePerQuintal, 341.2);

      // 2. Clear historical label (NOT live data)
      expect(benchmark.isLiveMandiData, false);
      expect(benchmark.isHistorical, true);
      expect(benchmark.isStale, true);
      expect(benchmark.hasLiveRecord, true);
      expect(benchmark.mandiName, contains('CEDA Historical'));
      expect(benchmark.market, 'APMC Market 168');
      expect(benchmark.arrivalDate, '2025-10-29');

      // 3. Gross Crop Value calculated consistently: 25 Qtl * 525.0 = 13,125
      expect(result.grossCropValue, 13125.0);

      // 4. Same calculation for kg input
      final kgInput = CropAnalysisInput(
        crop: tomatoCrop,
        location: 'Nashik',
        quantity: 100,
        quantityUnit: QuantityUnit.kilogram,
        harvestDate: DateTime.now().subtract(const Duration(days: 1)),
        condition: CropCondition.good,
      );
      final kgResult = await service.analyzeCrop(kgInput);
      expect(kgResult.grossCropValue, 100 * 5.25); // 525.0
    });

    test('Unit conversion: pricePerKg is exactly pricePerQuintal / 100.0', () {
      const benchmark = MarketPriceBenchmark(
        currentAvgPricePerQuintal: 525.0,
        predictedFuturePricePerQuintal: 341.2,
        minExpectedPrice: 367.5,
        maxExpectedPrice: 506.4,
        trend: PriceTrend.falling,
        expectedPriceChangePercent: -35.0,
        mandiName: 'APMC Market 168, Nashik (CEDA Historical)',
        district: 'Nashik',
        state: 'Maharashtra',
        arrivalDate: '2025-10-29',
        isHistorical: true,
        sourceName: 'CEDA Ashoka Agmarknet Historical Prices',
      );

      expect(benchmark.pricePerKg, 5.25);
      expect(benchmark.predictedFuturePricePerKg, 3.412);
    });
  });
}
