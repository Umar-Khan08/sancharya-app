import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/interfaces/i_agriculture_service.dart';
import '../../models/crop_model.dart';
import '../../models/crop_analysis_input.dart';
import '../../models/crop_analysis_result.dart';
import 'demo_agriculture_service.dart';
import 'local_mandi_service.dart';
import '../resources/mandi_discovery_service.dart';

/// Agmarknet Agriculture Service with offline-first local dataset (`assets/data/mandis.json`).
/// Directly loads local mandi price dataset so the app and APK never fail with "Unable to fetch data",
/// while retaining optional online backend connectivity for historical time-series forecasting when available.
class AgmarknetAgricultureService implements IAgricultureService {
  final DemoAgricultureService _fallbackService;
  final LocalMandiService _localMandiService;
  final Duration timeout;

  static const Duration defaultTimeout = Duration(seconds: 12);
  static const double minPlausibleMandiPricePerQuintal = 100.0;
  static const double maxPlausibleMandiPricePerQuintal = 50000.0;

  AgmarknetAgricultureService({
    DemoAgricultureService? fallbackService,
    LocalMandiService? localMandiService,
    this.timeout = defaultTimeout,
  })  : _fallbackService = fallbackService ?? DemoAgricultureService(),
        _localMandiService = localMandiService ?? LocalMandiService();

  @override
  bool get isDemonstrationProvider => false;

  String get _backendBaseUrl {
    const overrideUrl = String.fromEnvironment('BACKEND_URL');
    if (overrideUrl.isNotEmpty) return overrideUrl;

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Sends HTTP GET with automatic Android emulator host fallback (10.0.2.2 <-> 127.0.0.1)
  Future<http.Response> _getWithHostFallback(Uri uri, Duration requestTimeout) async {
    try {
      return await http.get(uri).timeout(requestTimeout);
    } catch (e) {
      if (!kIsWeb && Platform.isAndroid) {
        final altHost = uri.host == '10.0.2.2' ? '127.0.0.1' : (uri.host == '127.0.0.1' ? '10.0.2.2' : null);
        if (altHost != null) {
          try {
            final fallbackUri = uri.replace(host: altHost);
            return await http.get(fallbackUri).timeout(requestTimeout);
          } catch (_) {}
        }
      }
      rethrow;
    }
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

    String? district;
    String? state;
    if (input.location.isNotEmpty) {
      final parts = input.location.split(',');
      if (parts.isNotEmpty) district = parts[0].trim();
      if (parts.length > 1) state = parts[1].trim();
    }

    // Launch parallel resource & weather analysis (weather, spoilage, cold storage, NGOs)
    final fallbackWatch = Stopwatch()..start();
    final fallbackAnalysisFuture = _fallbackService.analyzeCrop(input).then((res) {
      debugPrint('[TIMING] Parallel resource & weather analysis took ${fallbackWatch.elapsedMilliseconds}ms');
      return res;
    });

    // =========================================================================
    // MANDI PRICE RETRIEVAL IN REQUIRED SOURCE ORDER:
    // 1. Primary: data.gov.in current daily mandi-price resource 9ef84268-d588-465a-a308-a864a43d0070
    // 2. Secondary: CEDA Agri-Market (only if verified and confirmed in official docs)
    // 3. Final offline option: existing assets/data/mandis.json via LocalMandiService
    // =========================================================================

    // STEP 1: Attempt Primary data.gov.in via backend API
    Map<String, dynamic>? backendMandiData;
    try {
      final queryParams = <String, String>{'commodity': cropName};
      if (district != null && district.isNotEmpty) queryParams['district'] = district;
      if (state != null && state.isNotEmpty) queryParams['state'] = state;
      if (input.latitude != null) queryParams['latitude'] = input.latitude.toString();
      if (input.longitude != null) queryParams['longitude'] = input.longitude.toString();

      final uri = Uri.parse('$_backendBaseUrl/api/mandi-prices').replace(queryParameters: queryParams);
      // Fast bounded network query to backend
      final response = await _getWithHostFallback(uri, const Duration(seconds: 4));

      if (response.statusCode == 200) {
        backendMandiData = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[AgmarknetApiService] Primary backend API connection skipped/timeout: $e');
    }

    final fallbackResult = await fallbackAnalysisFuture;

    // SCENARIO 1: Primary data.gov.in returned verified live records for this district
    // Must be verified genuine live data (is_live_data == true). The backend MANDI_CSV_PATH
    // configuration must NOT replace or preempt the required Flutter offline fallback (LocalMandiService & assets/data/mandis.json).
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
        );
        debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (Primary data.gov.in)');
        return res;
      }
    }

    // STEP 2: Secondary CEDA Agri-Market Historical Prices
    // Only accepted if backend returned verified CEDA historical observations with provenance.
    // Never labeled as live; clearly marked as historical observation with actual date and source.
    if (backendMandiData != null &&
        backendMandiData['success'] == true &&
        backendMandiData['records'] is List &&
        (backendMandiData['records'] as List).isNotEmpty &&
        backendMandiData['fallback_level'] == 'district' &&
        (backendMandiData['active_source'] == 'ceda' ||
            (backendMandiData['source']?.toString().contains('CEDA') ?? false) ||
            ((backendMandiData['records'] as List).first['source_name']?.toString().contains('CEDA') ?? false))) {
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
          isLive: false,
          isStale: true,
          isHistorical: true,
          sourceName: 'CEDA Agri-Market Historical Prices (Ashoka University)',
          sourceUrl: 'https://api.ceda.ashoka.edu.in/documentation/',
        );
        debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (Secondary CEDA historical fallback)');
        return res;
      }
    }

    // STEP 3: Final Offline Option — assets/data/mandis.json via LocalMandiService
    final localMatch = await _localMandiService.findPriceForCropAndLocation(
      cropQuery: cropName,
      locationQuery: input.location,
      latitude: input.latitude,
      longitude: input.longitude,
    );

    if (localMatch != null && localMatch.pricePerQuintal > 0) {
      final mandi = localMatch.mandi;
      final qPrice = localMatch.pricePerQuintal;
      final kgPrice = localMatch.pricePerKg;

      debugPrint('SANCHARYA: Offline Local Mandi Match for $cropName in ${mandi.district}: ₹$qPrice/Qtl (₹$kgPrice/kg) at ${mandi.nameEn}');

      final distKm = (input.latitude != null && input.longitude != null && mandi.latitude != 0.0 && mandi.longitude != 0.0)
          ? MandiDiscoveryService.calculateDistanceKm(input.latitude!, input.longitude!, mandi.latitude, mandi.longitude)
          : null;

      final res = await _buildLiveAnalysisResult(
        input: input,
        fallbackResult: fallbackResult,
        liveModalPrice: qPrice,
        liveMinPrice: (qPrice * 0.9).roundToDouble(),
        liveMaxPrice: (qPrice * 1.1).roundToDouble(),
        market: mandi.nameEn,
        district: mandi.district,
        state: mandi.state,
        arrivalDate: mandi.lastVerifiedDate,
        fallbackLevel: 'district',
        requestedDistrict: district,
        distanceKm: distKm,
        isLive: false,
        isStale: true,
        isHistorical: false,
        sourceName: 'Local Mandi Dataset (assets/data/mandis.json)',
        sourceUrl: localMatch.sourceUrl,
        lastVerifiedDate: localMatch.lastVerifiedDate,
        dataQuality: localMatch.dataQuality,
      );

      debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (Offline Local Mandi Dataset fallback)');
      return res;
    }

    // STEP 4: No matching records anywhere — clean "Data Not Available" state without fabricated prices
    final bool isUpstreamError = backendMandiData != null && backendMandiData['fallback_level'] == 'error';
    final res = _buildUnavailableAnalysisResult(
      input: input,
      fallbackResult: fallbackResult,
      district: district,
      state: state,
      isError: isUpstreamError && district == null,
    );
    debugPrint('[TIMING] Total crop analysis completed in ${totalWatch.elapsedMilliseconds}ms (Data Not Available)');
    return res;
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

    if (liveModalPrice > 0 && district.isNotEmpty) {
      try {
        final forecastUri = Uri.parse('$_backendBaseUrl/api/forecasting/price-forecast').replace(
          queryParameters: {
            'commodity': input.crop.nameEn,
            'market': market,
            'district': district,
            'state': state,
            'horizon_days': '7',
            'current_price': liveModalPrice.toString(),
          },
        );
        final fResp = await _getWithHostFallback(forecastUri, const Duration(seconds: 8));
        if (fResp.statusCode == 200) {
          final fData = jsonDecode(fResp.body) as Map<String, dynamic>;
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
      } catch (_) {
        // Suppress price prediction when genuine historical model is unavailable
        predictedPrice = 0.0;
        isModelConnected = false;
        isGenuineHoldout = false;
        customNoticeEn = 'Prediction unavailable because sufficient historical price data is not available.';
        customNoticeHi = 'पर्याप्त ऐतिहासिक मूल्य डेटा उपलब्ध नहीं होने के कारण पूर्वानुमान उपलब्ध नहीं है।';
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
                : '$market, $district (Offline Dataset)'));

    final noticeEn = isLive
        ? 'Verified live mandi price for $district (Arrival: $arrivalDate)'
        : (isHistorical
            ? 'Historical market observation for $district (Observed: $arrivalDate, CEDA Ashoka)'
            : (isDataGovInDb
                ? 'Verified database observation for $district (Arrival: $arrivalDate, data.gov.in)'
                : 'Offline Mandi Dataset Record for $district (Verified: ${lastVerifiedDate ?? arrivalDate})'));

    final noticeHi = isLive
        ? '$district के लिए सत्यापित लाइव मंडी भाव (आवक: $arrivalDate)'
        : (isHistorical
            ? '$district के लिए ऐतिहासिक मंडी रिकॉर्ड (अवलोकन: $arrivalDate, CEDA)'
            : (isDataGovInDb
                ? '$district के लिए सत्यापित डेटाबेस अवलोकन (आवक: $arrivalDate, data.gov.in)'
                : '$district के लिए ऑफलाइन मंडी डेटासेट रिकॉर्ड (सत्यापित: ${lastVerifiedDate ?? arrivalDate})'));

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
      distanceKm: distanceKm,
      forecastModelName: forecastModel,
      holdoutMape: holdoutMape,
      forecastHorizonDays: 7,
      forecastPeriod: forecastPeriod,
      isGenuineHoldout: isGenuineHoldout,
      historicalObservationCount: historicalObservationCount,
      isPredictionModelConnected: isModelConnected,
      isLiveMandiData: isLive,
      isDatasetRecord: !isLive && !isDataGovInDb && !isHistorical,
      isDatabaseRecord: isDataGovInDb,
      isStale: isStale,
      isHistorical: isHistorical,
      sourceName: sourceName ?? (isLive ? "data.gov.in" : (isDataGovInDb ? "data.gov.in (Database)" : "mandis.json")),
      sourceUrl: sourceUrl ?? (isLive ? "agmarknet.gov.in" : "mandis.json"),
      lastVerifiedDate: lastVerifiedDate ?? arrivalDate,
      dataQuality: dataQuality ?? (isModelConnected ? "Holdout Validated ($forecastModel)" : (isLive ? "Live Mandi Auction" : (isDataGovInDb ? "Verified Database Observation" : "Imported Mandi Dataset"))),
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

