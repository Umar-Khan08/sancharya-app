import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/interfaces/i_agriculture_service.dart';
import '../../models/crop_model.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';
import '../location/location_service.dart';
import 'demo_agriculture_service.dart';

/// Agmarknet Agriculture Service with verified online feeds (data.gov.in & CEDA Ashoka University).
/// The CEDA Agmarknet API and official data.gov.in feeds are the sole sources of mandi prices
/// and price-prediction inputs; static assets/data/mandis.json price substitution is completely eliminated.
class AgmarknetAgricultureService implements IAgricultureService {
  final DemoAgricultureService _fallbackService;
  final Duration timeout;
  final http.Client _client;
  final String? _customBackendBaseUrl;

  static const Duration defaultTimeout = Duration(seconds: 12);
  static const double minPlausibleMandiPricePerQuintal = 100.0;
  static const double maxPlausibleMandiPricePerQuintal = 50000.0;

  AgmarknetAgricultureService({
    DemoAgricultureService? fallbackService,
    this.timeout = defaultTimeout,
    http.Client? client,
    String? backendBaseUrl,
  })  : _fallbackService = fallbackService ?? DemoAgricultureService(),
        _client = client ?? http.Client(),
        _customBackendBaseUrl = backendBaseUrl;

  @override
  bool get isDemonstrationProvider => false;

  static const String defaultProductionBackendUrl = 'https://sancharya-backend.onrender.com';

  String get _backendBaseUrl {
    final customUrl = _customBackendBaseUrl;
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }
    const overrideUrl = String.fromEnvironment('BACKEND_URL');
    if (overrideUrl.isNotEmpty) return overrideUrl;

    return defaultProductionBackendUrl;
  }

  /// Sends HTTP GET with automatic Android emulator host fallback (10.0.2.2 <-> 127.0.0.1)
  Future<http.Response> _getWithHostFallback(Uri uri, Duration requestTimeout) async {
    debugPrint('[AgmarknetApiService] Fetching: $uri (timeout: ${requestTimeout.inSeconds}s)');
    try {
      return await _client.get(uri).timeout(requestTimeout);
    } catch (e) {
      debugPrint('[AgmarknetApiService] Fetch failed for $uri: $e');
      if (!kIsWeb && Platform.isAndroid) {
        final altHost = uri.host == '10.0.2.2' ? '127.0.0.1' : (uri.host == '127.0.0.1' ? '10.0.2.2' : null);
        if (altHost != null) {
          try {
            final fallbackUri = uri.replace(host: altHost);
            return await _client.get(fallbackUri).timeout(requestTimeout);
          } catch (_) {}
        }
      }
      rethrow;
    }
  }

  /// Fetches daily mandi prices from backend (/api/mandi-prices)
  Future<Map<String, dynamic>?> _fetchMandiPrices({
    required String cropName,
    String? district,
    String? state,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final queryParams = <String, String>{'commodity': cropName};
      if (district != null && district.isNotEmpty) queryParams['district'] = district;
      if (state != null && state.isNotEmpty) queryParams['state'] = state;
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();

      final uri = Uri.parse('$_backendBaseUrl/api/mandi-prices').replace(queryParameters: queryParams);
      final response = await _getWithHostFallback(uri, timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AgmarknetApiService] Mandi prices fetch skipped/timeout: $e');
    }
    return null;
  }

  /// Fetches historical mandi price observations and forecasts from CEDA backend (/api/forecasting/price-forecast)
  Future<Map<String, dynamic>?> _fetchCedaForecast({
    required String cropName,
    required String district,
    String? state,
    String? market,
    double? currentPrice,
  }) async {
    try {
      final queryParams = <String, String>{
        'commodity': cropName,
        'district': district,
        'horizon_days': '7',
      };
      if (state != null && state.isNotEmpty) queryParams['state'] = state;
      if (market != null && market.isNotEmpty) queryParams['market'] = market;
      if (currentPrice != null && currentPrice > 0) {
        queryParams['current_price'] = currentPrice.toString();
      }

      final uri = Uri.parse('$_backendBaseUrl/api/forecasting/price-forecast').replace(
        queryParameters: queryParams,
      );
      final response = await _getWithHostFallback(uri, timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AgmarknetApiService] CEDA forecast fetch skipped/timeout: $e');
    }
    return null;
  }

  @override
  Future<List<Crop>> getSupportedCrops() => _fallbackService.getSupportedCrops();

  @override
  Future<List<CombinedCropAnalysisResult>> getRecentAnalyses() =>
      _fallbackService.getRecentAnalyses();

  @override
  Future<CombinedCropAnalysisResult> analyzeCrop(CropAnalysisInput input) async {
    final totalWatch = Stopwatch()..start();
    final cropName = input.crop.nameEn;

    // Resolve location to canonical district and state
    String? district;
    String? state;
    final knownLoc = LocationService.lookupKnownCoordinates(input.location);
    if (knownLoc != null) {
      district = knownLoc.district;
      state = knownLoc.state;
    } else if (input.location.isNotEmpty) {
      final parts = input.location.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        district = parts[parts.length - 2];
        state = parts.last;
      } else if (parts.length == 1) {
        district = parts[0];
      }
    }
    if (district != null && (state == null || state.isEmpty)) {
      final distLookup = LocationService.lookupKnownCoordinates(district);
      if (distLookup != null && distLookup.state != null) {
        state = distLookup.state;
      }
    }

    // Launch parallel resource & weather analysis (weather, spoilage, cold storage, NGOs)
    final fallbackWatch = Stopwatch()..start();
    final fallbackAnalysisFuture = _fallbackService.analyzeCrop(input).then((res) {
      debugPrint('[TIMING] Parallel resource & weather analysis took ${fallbackWatch.elapsedMilliseconds}ms');
      return res;
    });

    // =========================================================================
    // MANDI PRICE RETRIEVAL IN REQUIRED SOURCE ORDER:
    // 1. Primary: data.gov.in current daily mandi-price resource / verified database records
    // 2. Secondary: CEDA Agmarknet API (Ashoka University) historical observations & forecasts
    // 3. Unavailable: Clean "Data Not Available" state. Never silently substitute static prices.
    // =========================================================================

    // Concurrently fetch daily mandi prices and CEDA forecast within configured timeout
    final mandiQueryFuture = _fetchMandiPrices(
      cropName: cropName,
      district: district,
      state: state,
      latitude: input.latitude,
      longitude: input.longitude,
    );

    final cedaQueryFuture = (district != null && district.isNotEmpty)
        ? _fetchCedaForecast(
            cropName: cropName,
            district: district,
            state: state,
          )
        : Future<Map<String, dynamic>?>.value(null);

    final results = await Future.wait([mandiQueryFuture, cedaQueryFuture]);
    final backendMandiData = results[0];
    final cedaData = results[1];
    final fallbackResult = await fallbackAnalysisFuture;

    // SCENARIO 1: Primary data.gov.in returned verified live or database records for this district
    if (backendMandiData != null &&
        backendMandiData['success'] == true &&
        (backendMandiData['is_live_data'] == true || backendMandiData['active_source'] == 'database') &&
        backendMandiData['records'] is List &&
        (backendMandiData['records'] as List).isNotEmpty &&
        backendMandiData['fallback_level'] == 'district') {
      final records = backendMandiData['records'] as List<dynamic>;
      Map<String, dynamic>? validRecord;
      for (final r in records) {
        if (r is Map<String, dynamic>) {
          final p = (r['modal_price_per_quintal'] as num?)?.toDouble() ?? 0.0;
          if (p >= minPlausibleMandiPricePerQuintal && p <= maxPlausibleMandiPricePerQuintal) {
            validRecord = r;
            break;
          }
        }
      }

      if (validRecord != null) {
        final topRecord = validRecord;
        final modalPrice = (topRecord['modal_price_per_quintal'] as num?)?.toDouble() ?? 0.0;
        final liveMinPrice = (topRecord['min_price_per_quintal'] as num?)?.toDouble() ?? (modalPrice * 0.9);
        final liveMaxPrice = (topRecord['max_price_per_quintal'] as num?)?.toDouble() ?? (modalPrice * 1.1);
        final rawMarket = topRecord['market']?.toString().trim() ?? 'Regional APMC Yard';
        final recDistrict = topRecord['district']?.toString().trim() ?? (district ?? '');
        final recState = topRecord['state']?.toString().trim() ?? (state ?? '');
        final arrivalDate = topRecord['arrival_date']?.toString().trim() ?? '';
        final distanceKm = (topRecord['distance_km'] as num?)?.toDouble();
        final isLive = backendMandiData['is_live_data'] == true;
        final isStale = topRecord['is_stale'] == true || backendMandiData['is_stale'] == true;
        final isHist = topRecord['is_historical'] == true || backendMandiData['is_historical'] == true;
        final activeSrc = topRecord['source_name']?.toString() ?? backendMandiData['source']?.toString();
        final isDb = backendMandiData['active_source'] == 'database' ||
            (activeSrc?.contains('Database') ?? false) ||
            ((activeSrc?.contains('data.gov.in') ?? false) && !isLive);

        final res = await _buildLiveAnalysisResult(
          input: input,
          fallbackResult: fallbackResult,
          liveModalPrice: modalPrice,
          liveMinPrice: liveMinPrice,
          liveMaxPrice: liveMaxPrice,
          market: rawMarket,
          district: recDistrict,
          state: recState,
          arrivalDate: arrivalDate,
          fallbackLevel: 'district',
          requestedDistrict: district,
          distanceKm: distanceKm,
          isLive: isLive,
          isDatabaseRecord: isDb,
          isStale: isStale,
          isHistorical: isHist,
          sourceName: activeSrc,
          sourceUrl: isLive ? 'https://data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070' : null,
          preloadedForecastData: cedaData,
        );
        debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (Primary data.gov.in)');
        return res;
      }
    }

    // SCENARIO 2: Secondary CEDA Agmarknet API Historical Observations & Forecasts
    // When primary daily data has no records for the district, use CEDA historical observations.
    // Crucial: do NOT supply a synthetic price — use genuine observed rate from CEDA.
    if (cedaData != null && (cedaData['success'] == true || cedaData['has_prediction'] == true)) {
      final cedaObservedPrice = (cedaData['current_observed_price'] as num?)?.toDouble() ?? 0.0;
      final bool hasValidCedaPrice = cedaObservedPrice >= minPlausibleMandiPricePerQuintal &&
          cedaObservedPrice <= maxPlausibleMandiPricePerQuintal;

      if (hasValidCedaPrice) {
        final cedaMarket = cedaData['market']?.toString().trim() ?? 'Regional APMC Yard';
        final cedaDistrict = cedaData['district']?.toString().trim() ?? (district ?? '');
        final cedaState = cedaData['state']?.toString().trim() ?? (state ?? '');
        final arrivalDate = cedaData['source_period_end']?.toString().trim() ?? '';
        final predictedPrice = (cedaData['predicted_future_price_per_quintal'] as num?)?.toDouble() ?? 0.0;
        final minExp = (cedaData['min_expected_price'] as num?)?.toDouble() ?? (cedaObservedPrice * 0.9);
        final maxExp = (cedaData['max_expected_price'] as num?)?.toDouble() ?? (cedaObservedPrice * 1.1);
        final changePct = (cedaData['expected_change_percent'] as num?)?.toDouble() ?? 0.0;
        final trend = _parseTrend(cedaData['trend']);
        final isHoldout = cedaData['is_genuine_holdout'] == true;
        final holdoutMape = (cedaData['holdout_mape'] as num?)?.toDouble();
        final modelName = cedaData['model_name']?.toString() ?? "Holt's Double Exponential Smoothing";
        final obsCount = (cedaData['historical_points_used'] as num?)?.toInt() ??
            (cedaData['observation_count'] as num?)?.toInt();
        final sourceName = cedaData['data_source']?.toString() ??
            'CEDA Agri-Market Historical Prices (Ashoka University)';
        final noticeEn = cedaData['disclaimer_en']?.toString();
        final noticeHi = cedaData['disclaimer_hi']?.toString();
        final isModelConnected = predictedPrice > 0;

        final benchmark = MarketPriceBenchmark(
          currentAvgPricePerQuintal: cedaObservedPrice,
          predictedFuturePricePerQuintal: predictedPrice,
          minExpectedPrice: minExp,
          maxExpectedPrice: maxExp,
          trend: trend,
          expectedPriceChangePercent: changePct,
          mandiName: '$cedaMarket, $cedaDistrict (CEDA Historical)',
          market: cedaMarket,
          district: cedaDistrict,
          state: cedaState,
          arrivalDate: arrivalDate,
          fallbackLevel: 'district',
          requestedDistrict: district,
          noticeMessageEn: arrivalDate.isNotEmpty
              ? 'Recorded market observation from CEDA Ashoka Agmarknet ($arrivalDate). Stored historical observation, not live streaming price.'
              : 'Recorded market observation from CEDA Ashoka Agmarknet. Stored historical observation.',
          noticeMessageHi: arrivalDate.isNotEmpty
              ? 'CEDA अशोका एगमार्कनेट से दर्ज मंडी भाव ($arrivalDate)। यह ऐतिहासिक रिकॉर्ड है, लाइव भाव नहीं।'
              : 'CEDA अशोका एगमार्कनेट से दर्ज मंडी भाव। यह ऐतिहासिक रिकॉर्ड है।',
          predictionNoticeEn: noticeEn,
          predictionNoticeHi: noticeHi,
          distanceKm: null,
          forecastModelName: modelName,
          holdoutMape: holdoutMape,
          forecastHorizonDays: 7,
          forecastPeriod: cedaData['source_period_start'] != null
              ? '${cedaData['source_period_start']} to ${cedaData['source_period_end']}'
              : null,
          isGenuineHoldout: isHoldout,
          historicalObservationCount: obsCount,
          isPredictionModelConnected: isModelConnected,
          isLiveMandiData: false,
          isDatasetRecord: false,
          isDatabaseRecord: false,
          isStale: true,
          isHistorical: true,
          sourceName: sourceName,
          sourceUrl: 'https://api.ceda.ashoka.edu.in/documentation/',
          lastVerifiedDate: arrivalDate,
          dataQuality: 'Holdout Validated ($modelName)',
          priceUnit: '₹/quintal',
        );

        debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (CEDA Agmarknet direct API: ₹$cedaObservedPrice/Qtl, pred: ₹$predictedPrice)');
        return CombinedCropAnalysisResult(
          analysisId: 'CEDA-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now(),
          input: input,
          spoilageRisk: fallbackResult.spoilageRisk,
          marketBenchmark: benchmark,
          recommendation: fallbackResult.recommendation,
          nearbyResources: fallbackResult.nearbyResources,
          isSimulatedModel: false,
          weatherData: fallbackResult.weatherData,
        );
      }
    }

    // SCENARIO 3: No matching records anywhere — clean "Data Not Available" state without fabricated prices
    final bool isUpstreamError = (backendMandiData == null) && (cedaData == null);
    final res = _buildUnavailableAnalysisResult(
      input: input,
      fallbackResult: fallbackResult,
      district: district,
      state: state,
      isError: isUpstreamError && (district == null || district.isEmpty),
    );
    debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (Data Not Available)');
    return res;
  }

  static PriceTrend _parseTrend(dynamic trendVal) {
    final s = trendVal?.toString().toLowerCase().trim() ?? '';
    if (s == 'rising' || s == 'up') return PriceTrend.rising;
    if (s == 'falling' || s == 'down') return PriceTrend.falling;
    return PriceTrend.stable;
  }

  Future<CombinedCropAnalysisResult> _buildLiveAnalysisResult({
    required CropAnalysisInput input,
    required CombinedCropAnalysisResult fallbackResult,
    required double liveModalPrice,
    required double liveMinPrice,
    required double liveMaxPrice,
    required String market,
    required String district,
    required String state,
    required String arrivalDate,
    required String fallbackLevel,
    required String? requestedDistrict,
    double? distanceKm,
    bool isLive = true,
    bool isDatabaseRecord = false,
    bool isStale = false,
    bool isHistorical = false,
    String? sourceName,
    String? sourceUrl,
    String? lastVerifiedDate,
    String? dataQuality,
    Map<String, dynamic>? preloadedForecastData,
  }) async {
    final forecastWatch = Stopwatch()..start();
    // 2. Fetch genuine holdout-evaluated price forecast from backend
    PriceTrend priceTrend = PriceTrend.stable;
    double trendPercentage = 0.0;
    double predictedPrice = 0.0;
    double minExp = liveMinPrice > 0 ? liveMinPrice : liveModalPrice;
    double maxExp = liveMaxPrice > 0 ? liveMaxPrice : liveModalPrice;
    bool isModelConnected = false;
    bool isGenuineHoldout = false;
    int? historicalObservationCount;
    String? forecastModel;
    double? holdoutMape;
    String? forecastPeriod;
    String? customNoticeEn;
    String? customNoticeHi;

    // Use preloaded forecast data if available and valid
    Map<String, dynamic>? fData = preloadedForecastData;
    if (fData == null || fData['has_prediction'] != true) {
      if (liveModalPrice > 0 && district.isNotEmpty) {
        try {
          final queryParams = <String, String>{
            'commodity': input.crop.nameEn,
            'market': market,
            'district': district,
            'horizon_days': '7',
            'current_price': liveModalPrice.toString(),
          };
          if (state.isNotEmpty) {
            queryParams['state'] = state;
          }

          final forecastUri = Uri.parse('$_backendBaseUrl/api/forecasting/price-forecast').replace(
            queryParameters: queryParams,
          );
          final fResp = await _getWithHostFallback(forecastUri, timeout);
          if (fResp.statusCode == 200) {
            fData = jsonDecode(fResp.body) as Map<String, dynamic>;
          }
        } catch (_) {
          // Suppress price prediction when genuine historical model is unavailable or unreachable
          customNoticeEn = 'Prediction unavailable because the forecasting service is currently unreachable.';
          customNoticeHi = 'पूर्वानुमान सेवा से संपर्क न हो पाने के कारण मूल्य अनुमान उपलब्ध नहीं है।';
        }
      }
    }

    if (fData != null) {
      customNoticeEn = fData['disclaimer_en']?.toString();
      customNoticeHi = fData['disclaimer_hi']?.toString();
      if (fData['success'] == true &&
          fData['has_prediction'] == true &&
          fData['is_genuine_model'] == true &&
          fData['predicted_future_price_per_quintal'] != null) {
        predictedPrice = (fData['predicted_future_price_per_quintal'] as num).toDouble();
        minExp = (fData['min_expected_price'] as num).toDouble();
        maxExp = (fData['max_expected_price'] as num).toDouble();
        trendPercentage = (fData['expected_change_percent'] as num).toDouble();
        final tStr = fData['trend']?.toString();
        priceTrend = tStr == 'rising' ? PriceTrend.rising : (tStr == 'falling' ? PriceTrend.falling : PriceTrend.stable);
        isGenuineHoldout = fData['is_genuine_holdout'] == true;
        isModelConnected = isGenuineHoldout;
        forecastModel = fData['model_name']?.toString();
        final rawMape = (fData['holdout_mape'] ?? fData['evaluation']?['model_mape']) as num?;
        holdoutMape = isGenuineHoldout ? rawMape?.toDouble() : null;
        forecastPeriod = isGenuineHoldout ? '${fData["source_period_start"]} to ${fData["source_period_end"]}' : null;
        final obsCount = (fData['observation_count'] ?? fData['evaluation']?['observation_count']) as num?;
        historicalObservationCount = isGenuineHoldout ? obsCount?.toInt() : null;
      }
    }
    if (predictedPrice == 0.0) {
      customNoticeEn ??= 'Prediction unavailable because sufficient historical price data is not available.';
      customNoticeHi ??= 'पर्याप्त ऐतिहासिक मूल्य डेटा उपलब्ध नहीं होने के कारण पूर्वानुमान उपलब्ध नहीं है।';
    }
    debugPrint('[TIMING] Price forecasting took ${forecastWatch.elapsedMilliseconds}ms');

    final bool isDataGovInDb = isDatabaseRecord ||
        (sourceName?.contains('Database') ?? false) ||
        ((sourceName?.contains('data.gov.in') ?? false) && !isLive);

    final mandiDisplay = isLive
        ? '$market, $district (Agmarknet Live)'
        : (isHistorical
            ? '$market, $district (CEDA Historical)'
            : (isDataGovInDb
                ? '$market, $district (data.gov.in Stored)'
                : '$market, $district (Agmarknet Record)'));

    final noticeEn = isLive
        ? 'Verified live mandi price for $district (Arrival: $arrivalDate)'
        : (isHistorical
            ? 'Historical market observation for $district (Observed: $arrivalDate, CEDA Ashoka)'
            : (isDataGovInDb
                ? 'Verified database observation for $district (Arrival: $arrivalDate, data.gov.in)'
                : 'Verified Agmarknet observation for $district (Arrival: $arrivalDate)'));

    final noticeHi = isLive
        ? '$district के लिए सत्यापित लाइव मंडी भाव (आवक: $arrivalDate)'
        : (isHistorical
            ? '$district के लिए ऐतिहासिक मंडी रिकॉर्ड (अवलोकन: $arrivalDate, CEDA)'
            : (isDataGovInDb
                ? '$district के लिए सत्यापित डेटाबेस अवलोकन (आवक: $arrivalDate, data.gov.in)'
                : '$district के लिए सत्यापित एगमार्कनेट अवलोकन (आवक: $arrivalDate)'));

    final liveBenchmark = MarketPriceBenchmark(
      currentAvgPricePerQuintal: liveModalPrice,
      predictedFuturePricePerQuintal: predictedPrice,
      minExpectedPrice: minExp,
      maxExpectedPrice: maxExp,
      trend: priceTrend,
      expectedPriceChangePercent: trendPercentage,
      mandiName: mandiDisplay,
      market: market,
      district: district,
      state: state,
      arrivalDate: arrivalDate,
      fallbackLevel: 'district',
      requestedDistrict: requestedDistrict,
      noticeMessageEn: noticeEn,
      noticeMessageHi: noticeHi,
      predictionNoticeEn: customNoticeEn,
      predictionNoticeHi: customNoticeHi,
      distanceKm: distanceKm,
      forecastModelName: forecastModel,
      holdoutMape: holdoutMape,
      forecastHorizonDays: 7,
      forecastPeriod: forecastPeriod,
      isGenuineHoldout: isGenuineHoldout,
      historicalObservationCount: historicalObservationCount,
      isPredictionModelConnected: isModelConnected,
      isLiveMandiData: isLive,
      isDatasetRecord: false,
      isDatabaseRecord: isDataGovInDb,
      isStale: isStale,
      isHistorical: isHistorical,
      sourceName: sourceName ?? (isLive ? "data.gov.in" : (isDataGovInDb ? "data.gov.in (Database)" : "CEDA Agri-Market Historical Prices")),
      sourceUrl: sourceUrl ?? (isLive ? "https://data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070" : "https://api.ceda.ashoka.edu.in/documentation/"),
      lastVerifiedDate: lastVerifiedDate ?? arrivalDate,
      dataQuality: dataQuality ?? (isModelConnected ? "Holdout Validated ($forecastModel)" : (isLive ? "Live Mandi Auction" : (isDataGovInDb ? "Verified Database Observation" : "Agmarknet Observation"))),
      priceUnit: '₹/quintal',
    );

    return CombinedCropAnalysisResult(
      analysisId: 'LIVE-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      input: input,
      spoilageRisk: fallbackResult.spoilageRisk,
      marketBenchmark: liveBenchmark,
      recommendation: fallbackResult.recommendation,
      nearbyResources: fallbackResult.nearbyResources,
      isSimulatedModel: false,
      weatherData: fallbackResult.weatherData,
    );
  }

  CombinedCropAnalysisResult _buildUnavailableAnalysisResult({
    required CropAnalysisInput input,
    required CombinedCropAnalysisResult fallbackResult,
    required String? district,
    required String? state,
    required bool isError,
  }) {
    final locLabel = district ?? (input.location.isNotEmpty ? input.location.split(',').first.trim() : 'Selected Location');

    final benchmark = MarketPriceBenchmark(
      currentAvgPricePerQuintal: 0,
      predictedFuturePricePerQuintal: 0,
      minExpectedPrice: 0,
      maxExpectedPrice: 0,
      trend: PriceTrend.stable,
      expectedPriceChangePercent: 0,
      mandiName: '$locLabel (${isError ? "Unable to fetch data" : "Data Not Available"})',
      district: district,
      state: state,
      fallbackLevel: isError ? 'error' : 'none',
      requestedDistrict: district ?? input.location,
      noticeMessageEn: isError ? 'Unable to fetch data. Please try again.' : 'Data Not Available',
      noticeMessageHi: isError ? 'डेटा प्राप्त करने में असमर्थ। कृपया पुनः प्रयास करें।' : 'डेटा उपलब्ध नहीं है',
      predictionNoticeEn: isError
          ? 'Prediction unavailable because live market prices could not be retrieved.'
          : 'Prediction unavailable because sufficient historical price data is not available.',
      predictionNoticeHi: isError
          ? 'लाइव मंडी भाव प्राप्त न हो पाने के कारण मूल्य अनुमान उपलब्ध नहीं है।'
          : 'पर्याप्त ऐतिहासिक मूल्य डेटा उपलब्ध नहीं होने के कारण पूर्वानुमान उपलब्ध नहीं है।',
      isPredictionModelConnected: false,
      isLiveMandiData: false,
      priceUnit: '₹/quintal',
    );

    return CombinedCropAnalysisResult(
      analysisId: 'ANALYSIS-${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      input: input,
      spoilageRisk: fallbackResult.spoilageRisk,
      marketBenchmark: benchmark,
      recommendation: fallbackResult.recommendation,
      nearbyResources: fallbackResult.nearbyResources,
      isSimulatedModel: false,
      weatherData: fallbackResult.weatherData,
    );
  }
}

